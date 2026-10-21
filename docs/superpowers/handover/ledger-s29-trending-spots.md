# Handover ledger: S29 Điểm chụp đang hot (#194)

Unit: #194 (S29.01-S29.06 and the variants on S02.01, S02.03, S04.01-S04.06, S06.01, S10.01, S12.01)
Branch: `plan/194-trending-spots` (rebased twice: onto `origin/develop` 6ef387f with #190, #152 and #205, then onto 3a785647 with #136), target `develop`
PR: https://github.com/thanhngochoang/booking/pull/282 (draft)
Plan: `docs/superpowers/plans/2026-10-08-s29-trending-spots.md`
Spec: `docs/superpowers/specs/2026-10-08-trending-spots-design.md`

Tasks 1-6 were done by an earlier agent before the SDD ledger existed (commits 5e2d2ba, 070eca0, fc9e82f, 1a788a9, 73bf27d, ad7eeae; after the second rebase 6ee375b6, c2844b02, dee4f02a, 6ab776c9, debc7998, 5d68f9a5). Their Step 1 facts below come from those commits, the plan and the two rebase reports, not from per-task reports. Tasks 7-9 were built with the SDD loop (implementer, reviewer, fix round); Task 8 ran after #136 landed.

## Scope delivered

- Domain (Tasks 1-2, 5): `spot.ts` (`SPOT_AREAS`, `regionOfArea`, `spotCovers`, `SPOT_EVENT_SLACK_M = 500`), `spot_schedule.ts` (`MAX_OPEN_SCHEDULES = 8`, `expandWeekly`, `scheduleConflicts`, `scheduleEditBlocks`, `priceFromOf`), `spot_slots.ts` (`slotsFor`), `spot_booking.ts` (`SpotInterval`, `SpotDay`, `spotDayId`, `SPOT_BOOKING_GAP_MINUTES = 15`, `clashes`, `freeStartTimes`, `freeSlots`, `assertSpotBooking`, `withInterval`, `withoutInterval`, `spotBusyAt`, `releaseSpotInterval`), `spot_schedule_use_cases.ts` (`saveSpotSchedule`, `cancelSpotSchedule`, `saveSlotOffer`, `closeSlotOffer`), `spot_ranking.ts`, `spot_score.ts`, `spot_admin.ts`, in-memory stores, spot and slot bookings in `create_booking.ts`, `create_payment.ts`, `commit_transition.ts`, `booking_sweeps.ts`, `reschedule.ts`, event tagging in `event_use_cases.ts`.
- Functions and rules (Tasks 3-4): callables `saveSpotSchedule`, `cancelSpotSchedule`, `saveSlotOffer`, `closeSlotOffer`; `infra/spot_firestore.ts`, `infra/live_spot.ts`, `infra/spot_rank_firestore.ts`; the daily `rankSpots` scheduled function; staff CLI `tools/spots.ts` and `scripts/spots-local.sh`; seed spots; Firestore rules for `spots`, `spot_rankings`, `spot_directory`, `spot_schedules`, `spot_slot_offers`, `spot_days`; Storage rule `spots/{spotId}/{file}`; 12 composite indexes (2 added in the final fix wave for the `lastDay` queries).
- App (Tasks 6-9): `lib/data/spots` (repository, rules, providers), core `SpotCard`, `SeasonTag`, `SlotGrid`, S29.01 and S29.02 plus the Home and Explore entries, the spot context in the booking flow (S04.01-S04.06) and S29.06, provider screens S29.03-S29.05 and the S06.01 entry, the spot field in S12.01 and the spot chip in S10.01.
- Decision 6 and 7 hooks into #136's studio code (after the second rebase, commit e35c601b): see the Rulings and the Step 1 section.

## Step 1 findings (real names)

### Tasks 1-6 (earlier agent; from commits and rebase reports)

- #139: `DomainError(code, field?)` and `findContactLeak(text)` reached develop through #190 (`contact_filter.ts`); #194 kept develop's copy. #194 added an optional third argument `DomainError(code, field?, details?)` (backwards compatible); `toHttpsError` merges `details` into the callable error, which is how `details.days` reaches the app.
- #190 (add-ons): `priceAddonLines`, `bookingTotal`, `requirePickup`, `expectedTotal`, `BookingAddon`/`BookingPickup`, the S04.06 place step with its own `ScreenCodes.bookPlace`. The package-at-a-spot path keeps add-ons and pickup; the slot path refuses both with `invalid_argument` (Decision 8).
- #152 (delivery): `BookingTx` delivery methods, `memory_booking_store.ts` kept #194's serialized `txTail` transaction runner and gained `getRefund` and the delivery methods.
- #136 (studio members, landed before Task 8): `ProviderOrderGate.orderProfile()` is required (the optional stand-in was deleted), `StudioRoster { relationOf, person }` and `AssigneeKind` live in `studio_ports.ts`, the Booking studio fields (`assigneeId`, `assigneeKind`, `assignStatus`, `assignedAt`, `assignments`) and `studioFieldsTo/FromFirestore` replaced #194's stand-ins, `DayState.full` exists, `studio_day_load` is #136's capacity record, `FirestoreStudioRoster` reads `photographers/{uid}.studioId`.
- #132 (discover): Home and Explore were reworked there; S29 adds the hot-spots section on Home (`homeHotSpots`) and the "Điểm chụp gần bạn" row on Explore.
- #140 (instant booking) was NOT on develop when Task 2 ran (no instant-booking code in `packages/domain/src`), so the candidate filter of Decision 17 does not exist. The rule is listed under Cross-unit requests below.
- Error codes added: `outside_schedule`, `slot_taken`, `day_conflict`, `schedule_limit`, `spot_archived`, `schedule_has_bookings` (Decision 5). Transport statuses: services/api 409 for `slot_taken`, `day_conflict`, `schedule_has_bookings`; 422 for `outside_schedule`, `spot_archived`; 429 for `schedule_limit`.
- Task 2 availability call sites (every one got an explicit `spot` rule; `grep -rn "getAvailabilityDay|setAvailabilityDay|deleteAvailabilityDay|setAvailabilityBooked|deleteAvailability|availability(" packages/domain/src`): `booking_ports.ts` (4), `booking_sweeps.ts` (2), `commit_transition.ts` (5), `create_booking.ts` (3), `create_payment.ts` (1), `event_ports.ts` (3), `event_use_cases.ts` (8), `memory_booking_store.ts` (5), `memory_event_store.ts` (2), `memory_spot_store.ts` (1), `reschedule.ts` (5), `spot_schedule_ports.ts` (2), `spot_schedule_use_cases.ts` (3), `studio_assignment.ts` (4).
- Screen-code constants (`app_flutter/lib/core/screen_codes.dart`, added with the mock): `ScreenCodes.spots` S29.01, `spotDetail` S29.02, `mySpotSchedules` S29.03, `spotScheduleEdit` S29.04, `spotSlotOffer` S29.05, `spotSlotPick` S29.06. The place step on S04 is `ScreenCodes.bookPlace` S04.06 (#190).
- The booking flow arguments `BookingFlowArgs.scheduleId/slotOfferId/start` and the router query keys `scheduleId`, `offerId`, `start` (routes `/u/:uid/book?scheduleId=&date=` and `/u/:uid/book?scheduleId=&offerId=&date=&start=`).

### Task 7 (booking from a spot, S29.06)

- `BookingFlowState` after #190: `addons`, `picks`, `pickupName`, `droppedAddonNames`, `applicableAddons`, `addonsVnd`, `totalVnd`, `transportAddon`, `needsPickup`, `payVnd`, `canContinue`. Controller: `ref.listen(currentContactProvider)`, Decision-11 `_entryStep` with `_userActed`, `_entryResolved`, `_addonsLoaded`, `applyPackages`, `applyAddons`, `setAddonQty`/`toggleAddon`, `setPickup`, `consumeDropped`. Kept unchanged; the spot context follows the same listen pattern.
- Steps: `steps/service_step.dart` (`AddonPickBlock`), `steps/place_step.dart` (S04.06, `book-pickup-field`), `steps/review_step.dart` (S04.03, `BookingSummary.extraLine`).
- New: `SpotBookingContext`, `bookingSpotContextProvider`, `BookingFlowState.spot/isSlot/availableStarts(now)`, core `SlotGrid` (none existed), `showSlotPickSheet`, `spotDayProvider((scheduleId, day))`, `FakeSpotRepository.spotDayError/spotDayReads`.
- There is no "start in the future" rule in `daySlots`; `availableStarts(now)` adds one.

### Task 8 (provider screens, after #136)

- `WorkScreen` body is `AsyncView<WorkDashboard>` over `workDashboardProvider` (reads `myWorkBookingsProvider`); the S06.01 entry sits under the `StatTileRow`. A studio's spot bookings carry `photographerId = studio`, so S29.03 counts days from the bookings stream (Decision 21), with no `spot_days` reads.
- Studio member list in the app: `myStudioRelationsProvider` (`StudioRelation`, filtered on `RelationStatus.active`: `memberId`, `memberName`, `memberAvatarUrl`). `studioMembersProvider` is the public S03.01 row and is not used.
- Provider type and gate in the app: `myIntroProvider` (`providerType`, `acceptingOrders`), `verifyStartReadyProvider`; packages: `myPackagesProvider`; own availability: `AvailabilityRepository.watchRange`; the picker's centre: `spotPhotographerSummariesProvider(uid)`.
- Gaps found in earlier code and fixed in this task: `cancelSpotSchedule` threw `schedule_has_bookings` without `details` (now `details.days: [{day, count}]`) and counted past days (now only days from today); `spotErrorOf` dropped the field of `not_accepting_orders`; `FakeSpotRepository.watchMine/watchMyOffers` never emitted the current list; `AvailabilityCalendar` gained `selectedDays` (multi-select).
- Rules: `availability/{uid}/days/{dayKey}` already has `allow read: if signedIn()`, so a studio can listen to a member's days.

### Task 9 (events and posts)

- Used as is: `spotCovers(s, p, slackM)` and `SPOT_EVENT_SLACK_M = 500`, `spotDirectoryProvider` (`SpotEntry`: `spotId, name, city, lat, lng, radiusM, cardUrl, inSeason, seasonMonths, hotScore`), `LocationState.location` (`ApproxLocation`), `foldVietnamese` (`lib/core/text_fold.dart`), `DomainError.field`.
- Added: `EventDetail.spotId/spotDecided`, `EventError.field` (read from `details.field`), persisted `EventRecord.spotDecided` (written by Functions only; events are `write: false` for clients), `AppIcons.placeOff`, `spotsForEvent` and `suggestSpotForPost` in `spot_rules.dart`, `PostDraft.spotId`.

## Decisions 1-23 as taken

Taken as written in the plan unless a Ruling below says otherwise.

1. Blockers: #190, #136 and #132 all landed before the end; the unit ran after #190 and Task 8 after #136.
2. Region: city-level `SPOT_AREAS` (`hcm`, `hn`, `dn`, `hue`, `da-lat`, `nha-trang`, `hoi-an`, `yen-bai`), `regionOfArea`; staff add new codes in code.
3. One `spot_directory/all` document read once per session; no `spots(areaCode, status, hotScore)` index.
4. Spot-day model: `availability/{holder}/days/{day}` = `{state: 'spot', scheduleId, spotId, updatedAt}` plus `spot_days/{scheduleId}_{day}` intervals; 15-minute gap, 0 inside one offer.
5. Error codes as listed above; a normal booking into a spot day answers the existing `day_taken`, not `day_conflict`.
6. Every availability path treats `spot` explicitly (call-site list above); the app keeps mapping unknown states to booked.
7. Studios: one named member per schedule; spot bookings are created already assigned and never enter `studio_day_load`; `assignBooking`, `requestAssigneeChange` and `returnAssignment` refuse them with `not_eligible`; `leaveStudio`/`removeMember` answer `member_busy` while the member is the assignee of an open schedule with a day from today (new `StudioTx.countOpenSpotSchedules`). The capacity reader treats a member's `spot` day as not free.
8. Slot bookings: synthetic `ServiceRecord` from the offer; `addons`/`pickup` refused.
9. The place is the spot (server sets it); S04.06 shows it locked.
10. Archived spots accept no new schedule or booking.
11. Schedule limits are race-proof through the `photographers/{uid}/private/spot_schedules` lock document; removing a day or narrowing the window under an interval is `schedule_has_bookings`; past days stay stored.
12. Ranking: `stats`, `hotScore`, hot list rules; the job writes only changed spots.
13. Posts: client-written, suggestion by name or radius; no moderation state yet (Deferred).
14. Events: server accepts `spotId: string | null`, centre within `radiusM + 500 m`; "Bắt buộc chọn" is an app rule.
15. No auto-accept (Needs the owner 1 default).
16. Reschedule of a spot booking is `not_eligible`.
17. Instant booking (#140): rule not implemented because #140 had not merged; see Cross-unit requests.
18. Not done: #139 (quotes) is not on develop, so there is no `withdrawQuotesForDay`. `handleSaveSpotSchedule` (`functions/src/callables/spot.ts`) has an optional `afterSave(holder, addedDays)` hook, but `index.ts` does not pass one, so saving a schedule withdraws no quote. See Cross-unit requests (#139).
19. Provider summaries on S29.02 come from the cached public provider; `priceFrom` is denormalised on the schedule.
20. Covers: the CLI resizes to `spots/{spotId}/cover.jpg` (1600) and `card.jpg` (480) with `sharp`, `Cache-Control: public, max-age=604800`.
21. S29.03 per-day counts come from the work screen's bookings.
22. Static map: no `MapPreview` existed (no #140), so S29.02 draws its own small tile in `spot_screen.dart`; "Chỉ đường" opens `https://www.google.com/maps/dir/?api=1&destination={lat},{lng}`.
23. Copy: plan strings, with the mock winning where they differ (listed below).

## Rulings (controller, for the owner; each costs a small change if wrong)

- Run Task 7 on develop right after the first rebase and Task 8 after #136; costs a second PR round if the owner had wanted one PR.
- S04.02 spot copy follows the mock ("Lịch tại điểm · {days} · {start}–{end}" and the end-time tail) over the brief's `bookSpotWindow`; the mock is the copy authority. Costs a string change.
- S29.06 date chips show only schedule days that still have free slots, in one horizontal row, as the mock caption says (spec §4 silent). Costs a list change if the owner wants full days shown.
- S29.02 "today" and the season month use Vietnam time (`vnDateKey`, `toVn`), fixing Task 6's UTC date; no downside.
- Spot field in S12.01 sits in step 1 as in mock `#S12.01-spot` (the brief had it in step 2). Costs a move.
- S12.01 spot suggestions are ordered covering-first, then nearest (spec "gần nhất trước"), although the mock caption says "điểm hot trước"; ordering is behaviour, so the spec wins. The owner may want to align the mock caption. Costs a sort tweak.
- Mock frame #223 (`docs/design/ui-mock.html` ~L4703, S30) will later replace the S12.01 spot field with three required choices; that is S30, not #194.
- Assigning a member who holds a spot day answers `day_taken` (#136's existing answer for a taken member day) instead of the plan's `member_busy`; one code for one situation. Costs a code swap.
- Task 8 mock-over-brief choices accepted: S29.03 app bar "Lịch tại điểm", text actions "Sửa" · "Gói chia suất" · "Huỷ lịch", S29.04 edit primary "Lưu thay đổi", S29.05 steppers (5-minute steps) and "Giao ảnh trong … ngày", sentence-form conflict lines.
- S06.01 entry shows the mock's "Lịch tại điểm · {n} đang mở" count (from `mySpotSchedulesProvider`) and stays under the S06.02 empty state too; a small addition, mock wins.
- `cancelSpotSchedule` and `saveSpotSchedule` ignore intervals on past days (beyond the Task 8 brief's file list; needed for the S29.03 case to be reachable and for edits after a past booking).
- `priceFromOf` refuses a listed package longer than the window; "Mọi gói" counts only packages that fit.
- A failed post publish with a spot tag drops the tag so the retry publishes without it (a rules refusal cannot be told from a network error).
- A studio spot booking (created already assigned) sends #138's `booking_assigned` to the customer and the member when it leaves the draft (`draft` → `requested`/`accepted`/`upcoming`), with the hook's own dedupe key; no new notification type (final fix wave).
- Branch and PR rebased twice instead of merged; commit messages and the TonyH trailer are unchanged.

## Final fix wave (after the whole-branch review)

The final review of `3a785647..cd68c125` asked for six Important and five Minor fixes; all were made in one wave (commits dd2ed8d2, 7599ba92 and the docs commit):

- S29.02 posts hide authors from #144's real block index (`hiddenUsersProvider` in `lib/data/safety/safety_providers.dart`); the stub in `spot_providers.dart` that returned `{}` is gone.
- Spot schedules store `lastDay` (the latest day, written on every save; `lastDayOf`, `scheduleLastDay`, `scheduleReachesDay` in `spot_schedule.ts`). `countOpenSpotSchedules` (studio leave/remove) and `openSchedulesOf` (the 8-schedule limit) query `lastDay >= today` with no limit, so old schedules never hide a current one and a save no longer reads the provider's whole history. A document without `lastDay` falls back to its days in the domain and the memory stores; Firestore cannot match it, so pre-wave emulator data needs a re-seed (Deploy order).
- A studio spot booking runs `orderBlocker` on the schedule's member before any write (`not_accepting_orders` / `blocked`), as `assignBooking` does.
- A studio spot booking created already assigned sends `booking_assigned` when it leaves the draft (Rulings).
- S29.02 providers (schedules + summaries), offers, events and photos each load behind `AsyncView` with their own skeleton (`SpotProviderCard.skeleton`, `SpotOfferCard.skeleton`, `EventCard.skeleton`, two photo tiles) and an error with retry; a failed or slow read no longer reads as "no providers".
- S29.06 date chips are capped to VN today..today + 14 (at most 15 `spot_days` reads on open); plan cost line, spec §10 and `screens/spots.md` amended.
- Reopening a closed slot offer counts against the 2 open offers of the schedule.
- A slot booking's `expectedPrice` (and `expectedTotal`) is checked against the offer read inside the transaction, and the booking is priced and timed from that read (`price_changed` when it moved).
- `FirestoreSpotRepository.schedule`/`offer` read a `permission-denied` (a cancelled schedule or closed offer seen by a customer) as null, so S04 shows "Lịch tại điểm vừa thay đổi".
- S29.02: the season line goes through l10n (`spotSeasonList`, also in `seasonLabel`), the photo alt text through the new `spotPhotoAlt` and the provider fallback name through `profileRolePhotographer`; hero colours come from `AppColors` (`surfaceMuted`, `foregroundMuted`, `overlay`, `onScrim`); the date picker uses the clock provider.
- Ruling: the S29.06 cap is strict. A day picked beyond the window with S29.02's "Chọn ngày" and then "Chọn suất" opens the sheet on the first day in the window (the viewed day has no chip). Costs one extra read per open if the owner wants the viewed day kept.

## Copy not in the spec or differing from the mock (Vietnamese verbatim)

From the plan, not in the spec:

- `spotSeasonAllYear` = "Đẹp quanh năm"
- `bookSpotPlaceLocked` = "Địa điểm là điểm chụp, không đổi được."
- `bookSpotWindow` = "Khung giờ tại điểm {start}–{end}": no longer in `app_vi.arb`; the fix round of Task 7 replaced it with the mock string `bookSpotScheduleLine` (below)
- `spotScheduleConflictFull` = "Studio hết chỗ"
- `slotOfferErrorFit` = "Khung giờ không đủ cho một suất"
- Error strings: `spotsLoadError` "Không tải được điểm chụp.", `spotNotFound` "Không tìm thấy điểm chụp.", `slotTakenError` "Suất này vừa có người đặt. Chọn suất khác.", `bookSlotTaken` "Giờ này vừa có người đặt. Chọn giờ khác.", `bookOutsideSchedule` "Lịch tại điểm vừa thay đổi. Chọn lại ngày giờ.", `bookSpotArchived` "Điểm này không còn nhận lịch mới.", `spotScheduleLimit` "Bạn đã có 8 lịch tại điểm đang mở. Huỷ bớt một lịch để mở lịch mới.", `spotScheduleError` "Không lưu được. Thử lại.", `spotScheduleNotAccepting` "Bạn cần được duyệt nhận đơn trước khi mở lịch tại điểm.", `eventSpotRequired` "Chọn một điểm chụp hoặc “Không thuộc điểm chụp nào”".

Added from the mock (not in the plan):

- Task 7: `slotPickDayLine` "{day} · còn {free} / {total} suất"; `slotPickOfferMeta` "Tại {spot} · {edited} ảnh chỉnh · giao trong {days} ngày. Gói chia suất không kèm dịch vụ đi kèm."; `bookSpotDaysOnly` "Chỉ ngày có lịch tại điểm"; `slotPickDays` "Ngày chụp"; `slotPickTimes` "Giờ bắt đầu"; `bookSpotScheduleLine` "Lịch tại điểm · {days} · {start}–{end}"; `bookSpotEndsAt` "{start}–{end} · chỉ giờ còn trống trong khung {from}–{to} của {name}"; `spotSlotsFull` "Hết suất".
- Task 8: `spotSchedulesOpenCount`, `spotSchedulesVerify`, `spotSchedulesRule`, `spotScheduleDaysRange`, `spotScheduleSummary`, `spotSchedulePackagesCount`, `spotSchedulePackagesAll`, `spotScheduleMoreDays`, `spotScheduleDayCountsLabel`, `spotScheduleNoBookings`, `spotScheduleNoOffers`, `spotScheduleNoBookingsNoOffers`, `spotScheduleOfferMeta`, `spotScheduleEdit`, `spotScheduleOffersAction`, `spotScheduleCancelKeep`, `spotScheduleCancelFailed`, `spotScheduleLimitCount`, `spotScheduleSpotPick`, `spotScheduleSpotNone`, `spotScheduleSpotRequired`, `spotScheduleMemberRequired`, `spotScheduleNoMembers`, `spotScheduleMemberNotAccepting`, `spotScheduleDaysLabel`, `spotScheduleStart/End`, `spotScheduleConflictPending`, `spotScheduleConflictHint`, `spotScheduleRemoveDay`, `spotScheduleUpdated`, `spotScheduleNoPackages`, `spotSchedulePackagesInvalid`, `spotScheduleConflictDay` "{day} ×", `spotNameCity`, `spotCitySeason`, `slotOfferDismiss`, `slotOfferScheduleLine`, `slotOfferDeliveryUnit`, `slotOfferMinutesRange`, `slotOfferGapRange`, `slotOfferLess/More`, `slotOfferNote`, `slotOfferKeep`, `slotOfferErrorPhotos/Edited/Delivery`, `slotOfferClosed`, `workSpotSchedulesSub`. Conflict sentences: "{day} đã có booking ở nơi khác." / "…đang có booking chờ nhận." / "…bạn đã đánh dấu nghỉ." / "…đã có lịch tại điểm khác." / "…studio hết chỗ." with "Bỏ ngày này để mở lịch." and the label "Giá mỗi suất".
- Final fix wave: `spotPhotoAlt` = "Ảnh chụp tại {name}" (screen-reader label of a photo tile without a caption).
- Task 9: sheet button for none "Không gắn điểm"; `eventSpotFar` = "Địa điểm nằm ngoài điểm chụp đã chọn. Sửa địa điểm hoặc chọn điểm khác." (the plan's "Địa điểm sự kiện nằm ngoài điểm chụp này" is not used); `eventSpotArchived` = "Điểm chụp này không còn nhận lịch mới. Chọn điểm khác."; `eventSpotGone` = "Không tìm thấy điểm chụp này. Chọn điểm khác."; `eventSpotNoMatch` = "Không có điểm chụp nào khớp."; `spotSchedulePackagesInvalid` = "Có gói không dùng được trong khung giờ này. Chọn lại gói."; `eventSpotLoadError` was removed.

## Skipped suites

Written, not run (the sandbox cannot run the emulators; CI does): Firestore rules tests (`app_flutter/firebase/rules-test/rules.test.mjs`, S29 block and the three post `spotId` tests), Storage rules tests (`spots/{spotId}/{file}`) and Functions integration tests (`test/integration/spot_booking.test.ts`, including `parallel createBooking on one slot → one slot_taken`). `services/api` vitest needs Docker and Postgres and was not run (`tsc --noEmit` is clean). Final numbers on the second rebase: domain 1726 (1730 after the Task 8 fix round), Functions 656, `dart run tool/affected_test.dart origin/develop --run` 4225 pass and 42 skipped. After the final fix wave: domain 1736, Functions 660, affected 4234 pass and 42 skipped. `flutter analyze` shows only the six errors under `firebase/functions/node_modules` (the `firebase-tools` 15 template; not tracked code). TDD red output is missing for Tasks 8 and 9 and for the SlotGrid test (stated in their reports).

## Deploy order and the Blaze switch

1. Firestore indexes first: the ranking job's count queries and the S29.02 queries (`spot_schedules`, `spot_slot_offers`, `posts(spotId, createdAt)`, `events(spotId, status, startAt)`, `bookings(spotId, depositPaidAt)`) fail without them. Those indexes are in `app_flutter/firebase/firestore.indexes.json`, with two for the bounded open-schedule queries: `spot_schedules(providerId, status, lastDay)` (`openSchedulesOf`) and `spot_schedules(providerId, assigneeId, status, lastDay)` (`countOpenSpotSchedules`). Schedules written before the final fix wave have no `lastDay` and are not matched by those queries: re-run the emulator seed (`scripts/backend-local.sh --seed`) or save each schedule once; there is no production data yet.
2. Cloud Functions: the four spot callables, the updated `createBooking`/`createPayment`/event functions, and the new Cloud Scheduler job `rankSpots` (daily 03:00 Asia/Ho_Chi_Minh, the 10th scheduled function). It deploys only when `BLAZE_ENABLED` is `true`.
3. Firestore rules, then Storage rules (`spots/{spotId}/{file}`; Storage deploys only behind `BLAZE_ENABLED`).
4. Staff add the first real spots (below), then run `rankSpots` once (or wait for 03:00) so `spot_rankings` and `spot_directory/all` exist; until then Home shows no hot-spots row.
5. App release.

The dev project `booking-c1922` is on the Spark plan and `BLAZE_ENABLED` is off (owner, 2026-10-09): Functions and Storage do not deploy there, only Firestore rules and indexes do, and the app runs on the emulators (`scripts/backend-local.sh`). `scripts/spots-local.sh rank` replaces the scheduled job there; `scripts/spots-local.sh list|add|pin …` runs the staff CLI against the emulators. Nothing in this unit adds a deploy step outside the Blaze switch. Cost spec: `rankSpots` adds one Scheduler job (+$0.10/month beyond the free 3), and the unit's estimate is about +$0.5/month at 1,000 MAU and +$3.9/month at 10,000 MAU (worst case +$13.2 with added photo views; plan "Chi phí Google").

## Staff steps

- Real spots: `npm --prefix app_flutter/firebase/functions run spots -- add --name <n> --city <c> --area <a> --lat <lat> --lng <lng> --radius <m> [--season 10,11,12] [--cover <file.jpg>] [--card <file.jpg>] [--description <d>] [--tip <t>]... --actor <uid>`; `--cover` uploads and resizes one JPEG into `cover.jpg` and `card.jpg` (needs `STORAGE_BUCKET` and, in production, `GOOGLE_APPLICATION_CREDENTIALS`). `--actor` must hold the custom claim `staffRole = admin`.
- Other commands: `spots list [--area <code>]`, `spots edit <id> …`, `spots pin|unpin|hide|unhide|archive <id> --actor <uid>`, `spots rank`.
- A new city needs a code added to `SPOT_AREAS` in `packages/domain/src/spot.ts` (and a deploy).
- Seed accounts and seed spots for the emulators: `app_flutter/firebase/functions/seed/README.md`, section "Điểm chụp (S29)".

## Deferred minors (from task reviews and rebases)

- Days outside the schedule read "nghỉ" to screen readers (needs a core `AvailabilityCalendar` label hook and a string).
- `SlotGrid` gap is 8 px (mock 6, no token); the S29.06 skeleton cell is 64 px (no 72 token).
- Any post publish failure drops the spot tag with the generic toast (no "đã bỏ gắn điểm" message); A → none → B keeps A's auto-filled place.
- Pruning every ticked package silently widens to "Mọi gói"; "Mọi gói" with no fitting package shows the generic packages-invalid copy.
- The seed's unassigned Cúc booking (20 h ahead) may land on An's seed spot day without a `full` mark (the live trigger recomputes it).
- `graphify-out/` is a textual merge of two regenerated graphs; regenerate it if it matters.
- Develop issues seen while rebasing, not touched: the duplicate ARB key `profileSavePhotographer`, "bất biến 25" for add-ons in `relational-schema.md` (it is invariant 28), `flutter analyze` errors from `firebase-tools` templates when the Functions dependencies are installed, and `flutter test` not running on arm64 with the project-local x86_64 engine (run by CI or the user).

## Open questions for the owner

1. Needs the owner 1: should a slot or spot booking be confirmed without the provider accepting it? Default taken: no (Decision 15).
2. Needs the owner 2: one named member per studio schedule, fixed until cancelled? Default taken: yes (Decision 7).
3. Needs the owner 3: archived spot also stops new bookings on schedules already open? Default taken: yes (Decision 10).
4. Needs the owner 4: photo egress of the spot-page masonry (up to about $9/month at 10,000 MAU until thumbnails exist). Default taken: 9 lazy first-image tiles, thumbnails as their own unit.
5. S29.06 date chips hide full days (mock caption). Show them dimmed instead?
6. Spot suggestions in S12.01: nearest-first with covering spots first (spec) or "điểm hot trước" (mock caption). The mock caption should be aligned.
7. Assigning a member who holds a spot day answers `day_taken` instead of the plan's `member_busy`. Keep?
8. The mock frame #223 (S30) will replace the S12.01 spot field with three required choices; confirm that S30 owns that change.
9. The `sharp` CLI cover resize needs a real bucket; confirm who runs the first `spots add` once Blaze is on.

## Cross-unit requests (the controller posts the issue comments; nothing was posted from this task)

- #140 (S13-S14 instant booking, not merged when Task 2 ran): "S29 (#194): a photographer whose `availability/{uid}/days/{today}` is `{state: 'spot', scheduleId}` is not an instant candidate while `now` is inside that schedule's window; use `spotBusyAt(record, schedule, now)` from `packages/domain/src/spot_booking.ts`." Its map preview may reuse the drawn tile in `spot_screen.dart` (S29.02 has its own because `MapPreview` did not exist).
- #195 (automatic hotness and discovery) and #196 (save/follow spots, S17 notifications) build on these names: `spots.stats` (`posts14d`, `events`, `bookings14d`, `openSchedules`, `providersWeek`, `providersWeekend`), `spots.hotScore`, `spot_rankings/{areaCode}`, `spot_directory/all` (one document, ≤ 1 MiB up to about 2,500 spots), `spot_days`, and the pure ranking code in `packages/domain/src/spot_ranking.ts` and `spot_score.ts`. #196's "vào mùa / có thợ mới" notifications can read `inSeason`, `seasonMonths` and `openSchedules`.
- #139 (quotes, not on develop): "S29 (#194): after #139 lands, wire `withdrawQuotesForDay` into `saveSpotSchedule`'s `afterSave`: pass `(holder, days) => withdrawQuotesForDay(jobDeps, holder, day, null)` for each added day as the third argument of `handleSaveSpotSchedule` in `app_flutter/firebase/functions/src/index.ts` (the hook in `callables/spot.ts` already runs after the commit and only logs a failure). A quote for a day that became a spot day can no longer become a booking (plan Decision 18)."
- #223 (S30): `Spot` has no owner or claim field yet; the S12.01 spot field is replaced there (mock ~L4703).
- #161/S23 (staff dashboard): the CLI is the Phase 1 staff tool; the web screens for spots are Deferred.
- #90 (self-hosted): `services/api` has the new error statuses; tables `spots`, `spot_schedules`, `spot_schedule_days`, `spot_slot_offers`, `spot_day_intervals` are in `relational-schema.md` and the use cases are not ported.

## Deferred (not in this unit)

- Fully automatic hotness, personalised ranking and spot discovery from post clusters (#195, spec §11); save/follow spots and "vào mùa / có thợ mới" notifications (#196, S17).
- Add-ons on slot offers (spec T6, Phase 2); auto-confirming spot bookings (Needs the owner 1).
- Staff spot screens on the web dashboard (#161/S23, spec T7); the CLI is the Phase 1 tool. An `unarchive` command.
- Rescheduling a spot booking inside its schedule (Decision 16); reassigning a studio spot booking to another member (Decision 7); S27 collaborators as schedule assignees.
- Post moderation states (hidden, removed, pending) in the spot page query and the job's count; waits for the moderation state of #83/S23 (Decision 13).
- Thumbnails for post images and covers below 480 px (cost spec §11 unit), an interactive map on S29.02 (spec §11), any Maps API.
- Sharding `spot_directory/all` beyond about 2,500 active spots.
- Self-hosted parity: `services/api` routes and PostgreSQL migrations for `spots`, `spot_schedules`, `spot_schedule_days`, `spot_slot_offers`, `spot_day_intervals` (data-model docs updated in Tasks 1-2; code is phase 2, #90).
- Real payment intermediary and real payouts (fake rails only, owner ruling 2026-10-07).
