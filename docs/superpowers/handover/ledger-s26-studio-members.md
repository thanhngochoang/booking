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

`docs/design/ui-mock.html`: `S03.01-member`, `S05.02-studio-change`, `S06.01-studio`, `S06.01-member`, `S09.02-studio`, `S26.03-none`; `#S26.03` gains a "Từ chối" text button beside "Nhận"; `#S26.01` caption gains the empty state copy. Spec: studio-members-design §3.1 (relation id, public membership via `photographers.studioId`), §5.2 (deadline rule), §5.7 (assignee contact), §6 (reason label "Tư vấn chậm"); main spec §2 S26 rows now link #136.

## Rulings (decisions taken while building, with what each costs if wrong)

1. The claim branch is `plan/136-s26-studio-va-thanh-vien` (named by `project.py`), not the plan's `plan/136-s26-studio-members`. Cosmetic.
2. Needs-the-owner 1, 3 and 4 take the plan's defaults (Decisions 8, 17, 21), as the owner-approved spec says. One small change each if wrong.
3. #136 ran while #194 (also held by this machine) was paused, at the owner's request on 2026-10-21, so #194 Task 8 can build on it.
4. The S26 status cells in the main spec link `#136` instead of the plan's prose "có mock, đang làm", because the owner rule "Issue status = links" wins over the plan text.
5. A wrong caller on `respondInvite`, `respondJoinRequest` or `removeMember` gets `permission_denied`, consistent with the Contract refusal list and with `cancelInvite`/`cancelJoinRequest` (the brief's sample used `not_found`). The Contract is the interface authority; a code swap if wrong.
6. A member's personal booking is refused when the studio's unassigned bookings that day are at least the number of free members (counting this member as free). The literal "at least free members minus one" would block a lone member forever; after the personal booking the free count drops by one, and the studio is short only when unassigned exceeds it. One comparison to change if wrong.
7. Rescheduling a studio booking is refused with `not_eligible` in Phase 1 (the same pattern #194 uses for spot bookings), because `reschedule.ts` is not studio-aware and would write `booked` on the studio's day while leaving the load and the assignee's day alone. Costs a feature later, no data corruption. The app also hides "Đổi lịch" for every role on studio bookings.
8. Reassigning while a change request is pending sends the customer only `booking_reassigned` (no extra `change_answered`); the brief maps change answers to declined and expired only, which avoids a double notice. Costs one notice if the owner wants both.
9. The assignee gets unread counts in the booking chat (`send_message` counts members other than the sender), because Decision 16 makes the assignee a chat member. Small.
10. `assignBooking` re-checks the assignee's studio membership inside the transaction (`photographers/{assignee}.studioId == studio`), which closes the remove-versus-assign race. One extra in-transaction read.
11. A studio with zero assignable members (verified, not pending deletion) gets a server-written `photographers/{studio}.assignableMembers = 0`, kept up to date in `onPhotographerWrite`; the app treats 0 as every day full in S04.02 and in the next free date, while `createBooking` still refuses with `day_taken`. Per-day marks cannot express "no members". Costs one field and one app check; the owner may prefer hiding the studio from discovery instead (open question below).
12. A studio may set a `full` day to `off` (rules allow the owner's update `full` to `off`), which keeps the day closed when a booking cancels. Small.
13. The Dart side reads `assignableMembers` only for `providerType = studio`; when absent it falls back to `memberCount > 0` (not "all full"), and a present 0 means every day full. No production data yet (dev is on emulators) and the seed has the field. Costs one fallback branch.
14. "Duyệt" in S26.01 is disabled when members plus open invites reach the cap (the same rule as "Mời" in the invite sheet); the mock and spec are silent. Chosen for consistency, so no request is sure to fail. Costs re-enabling if the owner wants the server refusal shown.
15. `analysis_options.yaml` stays untouched (skill table rule); analyzer noise from `node_modules` is local only (CI does not install functions dependencies before analyze).
16. S05.02 gets "Trả việc" for the assignee while now is before the start and the job is not yet returned (Decision 14: any time before the start). Same-day jobs have no button today. Done in the final wave.
17. S05.05-studio keeps the shared "Chia sẻ ảnh" section (spec §6 is explicit) and the mock frame `#S05.05-studio` gained it, following the rule "update the mock when the spec is newer". Costs a mock edit.
18. S26.05 keeps the mock's fixed "Studio trả lời trong 6 giờ." with no `respondBy`; the mock wins on copy. The owner may want "trước {respondBy}" (open question below).
19. An unassigned booking past its start does not show the `overdue` copy promising a 100% cancel, because the fault right ends at the start. New keys `reviewNoAssigneeTitle` and `reviewNoAssigneeBody` cover it.
20. Payout ruling (final review): an unassigned studio booking is auto-cancelled at its start with a 100% refund (`cancel.by = studio_fault`, `reason = assign_overdue`, `cancel.at ≥ startAt`; action `cancel_unassigned_at_start` through `commitTransition`, `bookingClock` step `studioStartCancels`, index `bookings (assignStatus, status, day)`), counting `lateAssignCount` once if the overdue sweep had not; `shot`/`complete` are refused without an assignee for every role including system, and the app hides "Đã chụp". Both the customer and the studio get the system cancel notice ("Lịch … đã bị huỷ"), the customer also the refund notice; a customer's own `cancel_studio_fault` still tells only the studio. Money rule (100% held up front) and Decision 12. Costs: a studio that shoots without recording an assignee loses the booking; the owner may prefer keeping a cancellable fault after the start instead.

## Deferred minors (final review or later)

- Task 1: S26.03 and S26.03-none are both tagged "Mới" in the mock.
- Task 2: `inviteMember`'s open-pair conflict check still sees stale unswept `invited` relations, so a re-invite is blocked until the sweep runs.
- Task 3: a member leaving, being removed or setting an `off` day while the studio has unassigned bookings that rely on them can leave the studio short (Decision 26 covers personal bookings only). A permanently failing overdue notice blocks the critical mark (`lateAssignCount` never increments) and takes a sweep slot each run; a notice sent from the stale query snapshot can be spurious (deduped).
- Task 4: a missing display name is snapshotted as `''` in `viaStudioName` and `assigneeName` (the app treats `''` as no name); no test for a non-owner order on a studio booking; `studio: null` treated as absent is untested.
- Task 5: `assignableMembers` goes stale after studio to individual (ignored by the app); `recomputeStudioDays` runs sequential transactions in a trigger, unbounded (at most 31 days by 100); search may return fewer than 20; deleting an event hold does not re-mark `full` until the next recompute. `studioDayMark` leaves the studio's own non-full records alone (event hold or old individual booking): accepted.
- Task 6: `studio_booking.dart` line 168 `a['by'] as String?` throws on a non-string and drops the whole booking; the S06 calendar full-day tap comment and section copy; the quota is not recomputed at Vietnam midnight; `StudioError` drops `details.field`; the fake `membersOf` order differs from `studioJoinedAt`.
- Task 7: the S26.01 zero-size `AsyncView` pattern; an optional raw assigned provider in `booking_providers.dart`; spacing gap 2 to 4 dp and icons 16/18 to 20 (tokens). `_JobCard` is kept because the compact `BookingCard` shows place, a fixed title and a yellow badge against the mock.
- Task 8: "Mới · n đánh giá" for 1 to 4 reviews in the S26.04 meta; the studio card should show "đã trả việc" beside the assignee; the change row should be actionable only while now is before `respondBy`; unit tests for `myWorkBookingsProvider`; S04.02 preset day before the profile loads, past days painted full, next-free-date for `assignableMembers == 0`; `profileStudioNameProvider` duplicates `partyProfileProvider`; undisposed `ValueNotifier`s in the decline and return sheets; the S06.01 assigned stream swallows errors (consider surfacing).
- Task 9: a title-only `VerifyAlert` renders lighter than the mock `.warnc`; the 3-member chat display (owner and assignee as two provider-side senders) is unchecked.

- Final review: pre-existing, Firestore `findAutoCompletions` ignores its `cutoff` and stops at 100 results (unassigned studio bookings are now filtered after the query) — follow-up issue.
- Final review: the chat's `?reschedule=1` deep link reads the thread and booking with `ref.read` in the first post-frame callback, before their streams answer; in the widget test harness it opens nothing even for an individual booking, so it may be a no-op in the app too (studio bookings are now skipped explicitly) — check and follow up.

## Open questions for the owner

1. The studio's "N năm hoạt động" in S03.01: the mock only says "số năm hoạt động"; we use `skills.yearsExperience`. Is that the right source, or should it come from the studio's founding date?
2. S26.05 copy: keep the fixed "Studio trả lời trong 6 giờ." or show "trước {respondBy}" (the real deadline is `min(at + 6 giờ, startAt)`)?
3. A studio with `assignableMembers == 0`: keep it visible with every day shown full (what we built), or hide it from discovery?
4. Should "Duyệt" in S26.01 be disabled at the member cap (we did) or stay enabled so the server refusal `studio_full` is shown?
5. Still open from the brief: assignee phone channels for the customer (spec §5.7, Needs the owner 3) have no control in the mock.

## Skipped or missing verification

- Firestore rules tests (`app_flutter/firebase/rules-test`) and Functions integration tests (`npm run test:integration`) are written but not run here (the sandbox cannot run the emulator); CI runs them on push.
- No device or simulator build was done; the Flutter tests, analyzer, domain and Functions unit tests were run per task.
- TDD "RED first" evidence is missing on several tasks (reported by the implementers).
- Late-delivery hook: absent on develop, so `lateDeliveryCount` is stored but nothing increments it until #207.

## Deploy order and the Blaze switch

1. Indexes first (new queries on `bookings.assigneeId`, the sweep index `(assignStatus, assignOverdue, status, assignDeadline)`, `studio_members` and `photographers.studioId`), then Firestore rules, then Functions, then the app.
2. `BLAZE_ENABLED` is off: Functions and Storage do not deploy to dev; only Firestore rules and indexes deploy and the app runs on the emulators. No new Scheduler job was added: the studio sweeps run inside `bookingClock` as two clock steps, so there is nothing new behind the switch.
3. Existing photographers get `nameKey` on their next profile or user write (`onUserWrite` and `onPhotographerWrite` heal it); S26.02 cannot find older dev accounts until then.
4. Studio bookings created before this change have no studio fields and behave as individual bookings.
5. Account deletion reads `studio_members` by `memberId` and by `studioId` (the #205 fix in Task 5).

## S27 notes (Decision 9)

S27 "Studio tuyển thợ" (#151: collaborators who are not members, per-job acceptance, declared fee off the booking, `studio_collaborations`) is not built. The assignment model is ready: `assigneeKind` (today only `member`), `StudioRoster.relationOf` returns `'collaborator'` from S27's own collection, and everything goes through the one `assignBooking` entry point. Other deferred items: manager role, several owners, in-app money split, several assignees per booking, the customer pre-choosing a member, public violation counters, account deletion ending relations (`endedBy: system`, S22.02, #141), both tags on the real-shoot post in S02.02 (Decision 22), the `services/api` migration (#90) and staff screens for the counters (#83), and a real payment intermediary for studio-fault refunds (#129).
