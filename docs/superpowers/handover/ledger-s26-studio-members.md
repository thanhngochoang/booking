# Handover Ledger: S26 Studio và thành viên (#136)

- **Issue:** #136 · **Plan:** `docs/superpowers/plans/2026-10-07-s26-studio-members.md` · **Branch:** `plan/136-s26-studio-va-thanh-vien` (from `origin/develop` 6ef387f)

## Contract after #130

Checked on develop 6ef387f (with #130 reviews, #152 delivery, #198 order gate, #199 booking draft, #135 verification, #138 notifications, #134/#148 settings and work merged). Every later task uses the "real name" column.

### Domain and Functions

| Name in plan | Real name / location | Status |
|---|---|---|
| #130 `submitReview(deps, callerId, raw)` | `packages/domain/src/submit_review.ts`, same signature; returns `{review: Review; postId: string \| null}`; writes ONE doc `reviewDocId(bookingId,'photographer')`, one booking update, one event; callable `handleSubmitReview` returns `{postId}` | same (writes one doc; Task 4 adds the second) |
| `validateReviewInput(raw, callerId, prefixes, {studio})` | `review.ts` `validateReviewInput(raw, callerId, urlPrefixes)` (3 args, no options); returns `ReviewInput {bookingId, verdict, hits, reasons, text, postId, photos}` | differs: 4th param and `studio` block do not exist; Task 4 adds them |
| #130 review input names `verdict/hits/reasons` | `verdict: 'tomato'\|'brick'`, `hits` int 1..10 (`REVIEW_HITS_MAX`), `reasons: ReviewReason[]` (brick only), `text` 10..1000 graphemes, `photos`, `postId` | same |
| `REVIEW_REASONS` | `['late','not_as_portfolio','slow_delivery','attitude','price_changed','other']`; validated by `validateReasons(verdict, raw)` (not exported shape yet) | same; `STUDIO_BRICK_REASONS` missing (Task 4 creates) |
| `reviewDocId(bookingId, subjectType)` | `review.ts`: `'studio'` gives `{bookingId}_studio`; `REVIEW_SUBJECT_TYPES = ['photographer','studio']`; `Review` has `subjectType`, `subjectId`, `photographerId` (== subjectId), `intensity`, `countedAt` | same; `viaStudioId/viaStudioName/assigneeId/assigneeName` on Review missing (Task 4) |
| `isReviewable` | `review.ts`: status `approved` or `completed` | same |
| `ReviewTx` | `review_ports.ts`: `getBooking, getReview, setBooking, addBookingEvent, setReview, createPost` (sync setters) | same |
| `tomatoPct` fields | server stats on `photographers/{id}.stats`: `reviewCount, tomatoCount, brickCount, signedSum, tomatoPct (round(100*tomato/count)), score`; `TOMATO_PCT_MIN_REVIEWS = 5` ("Mới" below it); `review_stats.ts` `addVerdict`; `countReview(store, reviewId, now)` counts into `review.subjectId`; `onReviewWrite` handler calls `notifyReviewVerdict` per doc | same |
| Late-delivery hook (#130/#152 "exposes the hook") | NOT PRESENT. No `lateDeliveryCount`, no late-delivery handler anywhere. Late-delivery cancel is #207 (`2026-10-08`-era plan, committed as docs only in #267, not implemented) | missing, conditional in plan Decision 15 ("else ledger"): Task 3 does NOT add the one line; record in the final ledger that `lateDeliveryCount` is stored (field + `incrementStudioCounter` supports it) but nothing increments it until #207 |
| #152 `shot`, `delivered`, `approved` | `BOOKING_STATUSES` in `booking.ts` contains `shot, delivered, revision_requested, approved, completed, reviewed` | same |
| #152 `mark_shot` | `TransitionAction` in `booking_machine.ts`: `'accept' \| 'decline' \| 'cancel' \| 'upcoming' \| 'mark_shot' \| 'complete'(alias) \| 'finish' \| 'expire'`; `decideTransition(booking, action, actor, now, reason?)`; `roleOf(userId, booking)` returns `customer\|photographer\|null` (no assignee); `transitionBooking(deps, {bookingId, action, actorId?, reason?})`; `booking_sweeps.ts` auto-fires `mark_shot` as system | same; Task 3 changes `roleOf`/`transitionBooking` for the assignee |
| #152 late-delivery fields on Booking | `shotAt, deliveredAt, approvedAt, checkUntil, autoApproveAt, autoApproveNoticeAt, extraRound, samplesPurgeAfter, samplesPurged, deliveryRound`, `canDeliver(b, uid)` (delivery.ts: photographer only) | same |
| `deliveryNotices(before, after)` | `delivery.ts`; consumed in `src/triggers/booking_write.ts` `handleBookingWrite(event, chatDeps, updateChatId?, extras?{notify,badges}, discovery?)`; hooks called with `delivererId: after.photographerId` | same; Task 3 adds `studioBookingNotices` next to it |
| #198 `orderBlocker` | `order_gate.ts`: `orderBlocker(deps: OrderGateDeps, {customerId, providerId}) → 'not_accepting_orders' \| 'blocked' \| null`; `assertOrderAllowed(deps, parties)` throws; `OrderGateDeps {providers: ProviderOrderGate; blocks?: BlockGate}` | same |
| `BlockGate` | `block_ports.ts` `BlockGate.isBlockedEitherWay(a, b)`; `BookingDeps.blocks: BlockGate` (required); Functions `liveBlockGate()` in `infra/live_safety.ts` | same |
| `ProviderOrderGate.orderProfile(photographerId)` | `booking_ports.ts` `ProviderOrderGate` has ONLY `acceptsOrders(photographerId): Promise<boolean>`; implemented in `functions/src/infra/booking_readers.ts` (`acceptsOrders(data)`), faked in ~6 Functions tests as `providers: { acceptsOrders: async () => true }` | missing; Task 3 adds `orderProfile` (every fake gains it, or keep `acceptsOrders` and add optional method) |
| #199 `BookingDraftInput` / `buildBookingDraft` | `create_booking.ts`: `BookingDraftCore`, `BookingDraftInput`, `draftTotal`, `buildBookingDraft(i)`; `createBookingDraft(deps, raw)` calls `buildBookingDraft({id, customerId, photographerId, service, day, start, place, note, addons, pickup, now})` | same |
| `slot #136 (studio)` markers (3) | `create_booking.ts` L23 (import block), L47 (`// slot #136 (studio): readonly providerType?: ProviderType \| null;`), L105 (`// slot #136 (studio): ...studioDraftFields(i, core),`). `coreDraft(i)` is a private function returning `Booking`; `buildBookingDraft` does `const core = coreDraft(i); return {...core, ...studioDraftFields(i, core), ...addonDraftFields(i)}` already shaped for `studioDraftFields(i, core)` | same |
| #135 `businessVerified` | public field on `photographers/{uid}` (in rules `photographerServerFieldsUntouched` list, server-only); `verification_firestore.ts` reads/writes it; `business_verification.ts`; domain `VerificationDeps` provider record has `businessVerified: boolean`. NOT on `ProviderProfile` (provider_ports) | exists; `StudioProfile.businessVerified` is read by Task 2's own adapter |
| `rate_limited` | in `errors.ts` ERROR_CODES (#135) and `callables/errors.ts` TRANSPORT_CODE → `resource-exhausted` | same (do not re-add) |
| `membership_conflict`, `cooldown`, `member_busy`, `studio_full` | absent from `ERROR_CODES` and TRANSPORT_CODE | missing; Task 2 creates (transport: first three `failed-precondition`, `studio_full` `resource-exhausted`) |
| `/verify/business` | `lib/app/router.dart` L258; `settings_screen.dart` `_BusinessTile`; `ownerVerified` computed from `myIntroProvider` | same |
| #138 13 studio hooks | all 13 present in `notification_hooks.ts` L358–560 with the plan's argument names. Differences: `notifyBookingReassigned` also takes optional `reassignedAt?: string` (spec §7 says pass it); `notifyBookingAssigned/Reassigned/AssignOverdue` return `Promise<NotifyResult[]>`, others `Promise<NotifyResult>`; `notifyAssignReminder` has no actor; notification types (`studio_invite`, … `assignment_returned`) are in `notification.ts` / `notification_render.ts` | same (+`reassignedAt`) |
| `bookingClock` | `functions/src/scheduled/booking_clock.ts`: `handleBookingClock(deps = liveBookingDeps(), reminders?, extras: BookingClockExtras = {})`; `BookingClockExtras {verification?: {deps, notify}; delivery?: {notify; purge?}}`; each step in its own try/catch, order: sweeps, reminders, remindAutoApprovals, verification nudges, purge. Schedule defined in `index.ts` L232 with `BOOKING_CLOCK_OPTIONS` | same; Task 5 adds `studio?` to `BookingClockExtras` as a last step |
| #132 availability trigger | `triggers/availability_write.ts` `handleAvailabilityWrite(uid, dayKey, deps: DiscoveryDeps)` → `refreshNextFreeDate`; wired as `onAvailabilityWrite` in `index.ts` L765. It does not know about studios | exists; Task 5 adds the `recomputeStudioDay` call for members with a `studioId` |
| `DayState.full` / server `state: 'full'` | `lib/core/widgets/availability_calendar.dart`: `enum DayState { free, pending, booked, off }`, no `full`; rules `availability/{uid}/days/{day}` create allows only `state == 'off'` from the client; `AvailabilityDayRecord` in domain has `off\|booked\|pending` | missing; Task 5/6 (capacity, Decision 26) adds `full` to domain record, calendar enum and l10n |
| `BookingTx.incrementStudioCounter` / `StudioBookingTx` | absent; `BookingTx` (booking_ports.ts L107) has `setBooking`, `getAvailabilityDay`, `setAvailabilityDay`, … (async methods) | missing; Task 3 creates (`StudioBookingTx extends BookingTx`, memory + Firestore stores) |
| `StudioRoster`, `StudioStore`, `studio_*.ts`, `onUserWrite`, `nameKey` | none exist (`studio_address.ts` is the unrelated private studio address) | missing; Tasks 2, 3, 5 create |
| `onUserWrite` | only `onUserCreated` (`index.ts` L545) exists | missing; Task 5 creates |
| `ProviderTx.countOpenRelations`, `ProviderProfile.memberCount` | `provider_ports.ts`: `ProviderProfile {uid, providerType, onboardingComplete, artistSince, studioDistrict, studioCity}`; `ProviderTx {getProfile, countActiveBookings, countHeldPayments, setProviderType, setStudioAddress}` | missing; Task 2 adds |
| `Booking` studio fields, `BookingCancel.by 'studio_fault'` | none on `Booking`; `BookingCancel.by: 'customer'\|'photographer'\|'system'` | missing; Task 3 |
| `Chat.assigneeId`, `roleInChat` | not present (`chat.ts`, `booking_chat_sync.ts` exist) | missing; Task 3 |
| `Clock`, `IdGenerator` | `ports.ts` (`now()`, `newId()`) | same |
| `ProviderType` / `chosenTypeOf` | `provider_type.ts` `PROVIDER_TYPES = ['individual','artist','studio']` | same |

### Rules and indexes

| Item | Real state |
|---|---|
| bookings read for the assignee | ALREADY in `firestore.rules` (#134): `resource.data.get('assigneeId', null) == request.auth.uid` on `bookings/{id}` read. Not yet on `events` read, `private/contact` read (comment says "#136's") |
| `private/delivery` | photographer or approved customer only (assignee excluded: matches Decision 15) |
| `studio_members`, `studio_quota`, `studio_day_load` rules | absent; Task 5 |
| `photographerServerFieldsUntouched()` | list today: `providerType, artistSince, studioDistrict, studioCity, approvedAwardCount, acceptingOrders, followerCount, followerCountAt, businessVerified, deletionPending`; studio fields not yet added |
| `availability/{uid}/days` create | only `state == 'off'`, delete only own `off`; `full` is server-only by construction |
| `reviews/{id}` | read signed-in, write false (subject-aware already) |
| Indexes | `bookings (assigneeId ASC, status ASC)` exists; plan's four booking indexes and the `studio_members`/`photographers` ones are absent |

### Dart app

| Name in plan | Real name / location | Status |
|---|---|---|
| `assignedBookingsProvider`, `myWorkBookingsProvider` | `lib/data/booking/booking_providers.dart` L75, L100; `BookingRepository.watchAssignedBookings(uid)` | same |
| `studioRoutesReadyProvider` | `lib/features/settings/settings_links.dart` L12, default `false`; flip to `true` when `/me/studio` and `/studio/members` exist. Settings rows keyed `settings-studio-members` and `settings-my-studio` (`settings_screen.dart` L108–122), l10n `settingsStudioMembers`, `settingsStudioMembersBody`, `settingsMyStudio`, `settingsMyStudioBody` exist | same |
| `/studio/members`, `/me/studio` routes | referenced as paths only (`settings_screen.dart`, `delete_account_screen.dart` L341); no GoRoute | missing; Task 6+ |
| `VerdictPad` API | `lib/core/widgets/verdict_pad.dart`: `VerdictPad({key, required VerdictKind? kind, required int hits, required void Function(VerdictKind? kind, int hits) onChanged, bool compact = false, bool enabled = true})`; `compact` is the one-row studio-block variant (mock `.vpad.cp`); `kVerdictHitsMax`; used by `features/review/review_screen.dart` L300. Keys `verdict-tomato`/`verdict-brick`; semantics label `reviewPadLabel` | same (compact flag already there for the studio block) |
| `ReviewRepository.submit` | `lib/data/review/review_repository.dart`: `Future<String?> submit({bookingId, Verdict verdict, int hits, List<ReviewReason> reasons, String text, String? postId, List<ReviewPhoto> photos = const []})`; enum `Verdict {tomato, brick}`, `ReviewReason` (6 codes), `Review` has `subjectType` ('photographer'), `subjectId`, `intensity`; no `viaStudioName`/`assigneeName`; no `StudioReviewDraft` | differs (names `Verdict`/`VerdictKind` both exist: pad uses `VerdictKind`); `StudioReviewDraft`, `Review.viaStudioName/assigneeName` missing; Task 7 |
| `PhotographerSummary` | `lib/data/content/photographer_summary.dart`: has `tomatoPct` (int, `hasTomatoPct`), `reviewCount`, `businessVerified`, `providerType`; no `studioId`, `memberCount`; `PhotographerRepository.membersOf` absent | missing additions; Task 7 |
| `BookingAction` | `booking_repository.dart` `{accept, decline, cancel, complete, markShot}` with `code` (`markShot` → `'mark_shot'`); no `cancelStudioFault` | same; Task 7 adds |
| `StudioBookingInfo`, `MemberRow`, `MemberStrip`, `AssigneeCard`, `lib/data/studio/*` | none exist | missing; Tasks 6–8 create |
| `ScreenCodes` S26 | `lib/core/screen_codes.dart` L146–151: `studioMembers S26.01`, `inviteMember S26.02`, `myStudio S26.03`, `assignPhotographer S26.04`, `requestPhotographerChange S26.05`; all in the list (L287+); `test/core/screen_codes_test.dart` passes | same, no change needed |

## Findings the controller must act on

1. **#205 reads `studio_members` with the wrong field.** `functions/src/infra/account_firestore.ts` L141–158 (the `studio_members` query at L145–146, `.where('userId', …)` at L146) queries `studio_members.where('userId' == uid).where('status' == 'active')`; the contract names the fields `studioId` and `memberId` (no `userId`). Deleting an account therefore never sees a studio relation. A later task (Task 5, with the Firestore adapters) must change it to two queries (`memberId == uid` and `studioId == uid`, `status == 'active'`) and its unit test.
2. **No late-delivery hook exists** (see table). Decision 15's one-line increment is skipped; `lateDeliveryCount` is only a stored counter for now.
3. **No stop condition.** #152, #198, #199 and #135 are all merged on 6ef387f and every member the plan calls "create-if-absent" is either present or created by a named task. `orderProfile` and `StudioBookingTx` are missing but the plan creates them in Task 3.

## Mock frames added (Task 1)

`docs/design/ui-mock.html`: `S03.01-member`, `S05.02-studio-change`, `S06.01-studio`, `S06.01-member`, `S09.02-studio`, `S26.03-none`; `#S26.03` gains a "Từ chối" text button beside "Nhận"; `#S26.01` caption gains the empty state copy. Spec: studio-members-design §3.1 (relation id, public membership via `photographers.studioId`), §5.2 (deadline rule), §5.7 (assignee contact), §6 (reason label "Tư vấn chậm"); main spec §2 S26 rows now "⬜ có mock, đang làm (#136)".
