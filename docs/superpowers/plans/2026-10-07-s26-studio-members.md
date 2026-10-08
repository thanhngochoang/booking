# S26 · Studio và thành viên Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

> **Blocked by #130** (tomato/brick reviews and two-layer delivery: the review model `verdict/hits/reasons`, `VerdictPad`, `tomatoPct`, and the `shot → delivered → approved` booking states this plan builds on). **Soft dependency #135** (S21): `photographers.businessVerified` (30-member cap) and the `/verify/business` route; until #135 lands the cap stays 3 and the S26.01 link to S21.04 is hidden.

> **Rules emulator tests (2026-10-02, user):** this plan changes `firestore.rules` and indexes and adds Functions. Write the rules tests and Functions integration tests; do not run them, CI runs them. Record the skips in the ledger.

> **No battery/performance, device build or iOS steps** (standing rules in `RUN-ORDER.md`). **Money is fake (owner, 2026-10-07):** the 100% refunds of this plan go through the existing fake gateway and `commitTransition`.

> **Detail level (user, 2026-10-02):** exact interfaces, tests listed by name with expected behaviour, sample code only for the parts easy to get wrong.

**Goal:** A studio invites photographers (or approves their requests) under anti-spam limits, sees its members and assigns each studio booking to a free, verified member at least 24 hours before the shoot; the customer sees who will shoot, may ask for one change, and gets a 100% refund when the studio breaks the rule; the assigned member sees the job in Công việc and can hand it back; after delivery the customer reviews the member and the studio separately. The studio profile shows its members and a "Xin gia nhập" button for independent photographers; a member's profile says "Thành viên của {Studio}".

**Architecture:** Membership and assignment rules live in `packages/domain` (`studio_membership.ts`, `studio_use_cases.ts`, `studio_assignment.ts`, ports and in-memory stores). Functions are thin: 14 callables, one trigger `onUserWrite` (search key), and three more steps in the existing 15-minute `bookingClock` (overdue, reminders, change-request and invite expiry; no new Scheduler job). Firestore: `studio_members/{studioId}_{memberId}_{createdAtMs}` (two parties read, server writes), `studio_quota/{uid}`, studio fields on `photographers/{uid}` and studio bookings (`isStudio`, `assigneeId`, `assigneeKind`, `assignments[]`, `changeRequest`, `studioFault`…). Assignment is designed for a later S27 collaborator: the booking stores `assigneeKind` and the domain asks a `StudioRoster` port for the relation, so a non-member collaborator can be added without a migration. Reviews extend #130's `submitReview` with a second `reviews/{bookingId}_studio` document. The app gets `lib/data/studio/`, `lib/features/studio/` (S26.01–S26.05) and changes on S03.01, S05.02, S05.05, S06.01, S09.02.

**Tech Stack:** TypeScript (`packages/domain`, Functions v2 callables, `onDocumentWritten`, the existing `onSchedule`), Firestore rules and indexes; Flutter, Riverpod 3, go_router, freezed (`build_runner`), existing core widgets plus `MemberRow`, `MemberStrip`, `AssigneeCard`.

**Spec:** `docs/superpowers/specs/2026-10-06-studio-members-design.md` (all: T1–T12, §3 membership, §4 screens, §5 studio bookings, §6 two-sided reviews, §7 notifications, §8 rules, §10 tests); `2026-10-06-tomato-brick-reviews-design.md` §3.1 (review per subject), §4, §5, §6; `2026-10-06-delivery-preview-unlock-design.md` B5, §4 (studio delivers); `2026-10-06-identity-verification-design.md` V5, V6, §7 (`assignBooking` uses `ProviderOrderGate`); `docs/legal/terms-and-help-notes.md` S1–S5, R4; research `docs/research/2026-10-07-studio-collaborators.md` §0, "Giao việc" (S27 shape); mock `docs/design/ui-mock.html` `#S26.01`–`#S26.05`, `#S03.01-studio`, `#S05.02-studio`, `#S05.02-studio-late`, `#S05.05-studio`, `#S06.01`, `#S09.02`; cost rules `docs/superpowers/specs/2026-10-07-google-cloud-costs.md` §14.

**Issue:** #136 (S26 · Studio và thành viên). Branch `plan/136-s26-studio-members`, PR into `develop` titled `feat(studio): S26 studio members, assignment and two-sided reviews [#136]`.

**Execution wave:** 4 (cross-plan review 2026-10-07). **Blocked by:** #130 (reviews wave 2, delivery wave 3; hard), #135 (S21, wave 3: `businessVerified`, `/verify/business`, `rate_limited`), #144 (S20, wave 3: `orderBlocker` with its `BlockGate`), #129 (S04, wave 1, merged in #154; it did not build `buildBookingDraft` (now #152's, delivery plan Task 2) nor `orderBlocker` (now #144's, S20 Task 2), see `2026-10-08-s04-reconciliation.md`), #138 (S17, wave 1: the 13 studio notification hooks and their copy), #134 (S06, wave 2: `assignedBookingsProvider`, the assignee `bookings` read rule), #148 (S09, wave 1: settings rows and `studioRoutesReadyProvider`). #151 (S27, wave 5) builds on this plan.

## Contract with existing code

Checked 2026-10-07 on `develop` 812afd6 (before #130 and #135); #129's names re-checked 2026-10-08 on develop 87d8187 (`createBookingDraft` builds its booking inline; `buildBookingDraft` and `orderBlocker` come from #152 and #144). Task 1 Step 1 re-checks everything **after #130 has merged** and writes the actual #130 names into the ledger; later tasks use them. If a member named here does not exist, stop and report.

- Domain (`packages/domain/src`): `Booking` (`booking.ts`: `photographerId`, `day`, `start`, `end`, `status`, `cancel?: BookingCancel {by: 'customer'|'photographer'|'system', …}`, `version`), `BOOKING_STATUSES` (#130 adds `shot`, `delivered`, `approved`); `decideTransition`, `roleOf`, `TransitionAction` (`booking_machine.ts`; `accept` inside 24 h goes straight to `upcoming`; `upcoming` by system; `complete` photographer or system); `transitionBooking` (`transition_booking.ts`); `commitTransition` (`commit_transition.ts`: availability day of `photographerId`, refunds via `applyRefundToPayment` + `dispatchRefund`); `createBookingDraft` (`create_booking.ts`, calls `deps.providers.acceptsOrders`); `ProviderOrderGate { acceptsOrders }`, `BookingDeps`, `BookingTx.getAvailabilityDay/setAvailabilityDay/deleteAvailabilityDay` (`booking_ports.ts`; availability is **per day**: `{state: off|booked|pending, bookingId?}`); `parseVnDateTime` (`booking_policy.ts`); `runBookingSweeps` (`booking_sweeps.ts`); `bookingNotices`, `notifyBookingChange` (`booking_notifications.ts`); `Chat`, `chatIdFor(customerId, photographerId)`, `roleInChat` (`chat.ts`); `syncBookingChat` (`booking_chat_sync.ts`); `submitReview`, `ReviewDeps`, `ReviewTx` (`submit_review.ts`, `review_ports.ts`; #130 replaces `rating` with `verdict/hits/intensity/reasons`); `countReview(store, reviewId, now)` (`review_stats.ts`); `setProviderType` + `ProviderTx` (`set_provider_type.ts`, `provider_ports.ts`); `PROVIDER_TYPES` (`provider_type.ts`); `NOTIFICATION_TYPES`, `NotificationContent`, `renderNotification`, `formatDayShortVi`, `notify` (`notification*.ts`); `foldVietnamese` (`event_hashtag.ts`); `DomainError`, `ERROR_CODES`; `acceptsOrders`.
- Functions (`app_flutter/firebase/functions/src`): `CALLABLE_OPTIONS`, `TRIGGER_OPTIONS`, `REGION`; `toHttpsError`/`TRANSPORT_CODE`; `handleBookingClock(deps, reminders)` + `bookingClock` (`index.ts:125`); `FirestoreBookingStore` (`infra/booking_firestore.ts`) and the booking ↔ Firestore mapping; `FirestoreProviderOrderGate` (`infra/booking_readers.ts`); `toFirestoreChat` (`infra/chat_firestore.ts`, `members: [customerId, photographerId]`); `onBookingWrite` (`triggers/booking_write.ts`: chat sync + notifications); `handleReviewWrite` + `onReviewWrite` (`triggers/review_write.ts`; the path param is used as the booking id — this plan treats it as the review id); `handleSubmitReview` (`callables/review.ts`); `onUserCreated` (`index.ts:357`); `liveNotifyDeps`, `userDirectory` (`infra/user_directory.ts`); seed (`seed/fixtures.ts`: An `seed-photographer-an` verified individual, Cúc `seed-photographer-cuc` studio, Lan customer, Bình unverified).
- Rules: `match /bookings/{bookingId}` (read: customer or photographer; `private/contact` with `isBookingContactUnlocked`; `events`), `photographerServerFieldsUntouched()`, `match /chats/{chatId}` (members), `match /reviews/{bookingId}` (read signed-in), catch-all deny. Indexes: `bookings (photographerId, status)`, `(photographerId, createdAt desc)`, `reviews (photographerId, createdAt desc)`.
- App data: `Booking` freezed (`lib/data/booking/booking.dart`, `bookingFromFirestore`), `BookingRepository` (+ `BookingAction {accept, decline, cancel, complete}`), `FirestoreBookingRepository`, `bookingProvider`, `photographerBookingsStreamProvider` (`booking_providers.dart`); `PhotographerSummary` (+ #130 `tomatoPct`, `hasTomatoPct`, `formatTomatoPct`), `photographerSummaryFrom`, `PhotographerRepository` + `photographerRepositoryProvider` (`lib/data/content/`); `photographerProfileProvider` (`lib/data/photographer/public_profile_providers.dart`); `ReviewRepository.submit` (#130 shape) + `FirestoreReviewRepository`; chat models (`lib/data/chat/`, counterpart by role); `userRepositoryProvider`; `myIntroProvider` (+ `providerType` from #135 Task 5 if merged, else this plan adds it); `ProviderType`.
- App features/core: `BookingDetailScreen` (`features/booking/booking_detail_screen.dart`), `CancelSheet` (`cancel_sheet.dart`), `WorkScreen` + `_RequestCard` (`features/work/work_screen.dart`), `ReviewScreen` + `ReviewController` (`features/review/`), `ProfileHeader`, `ProfileBottomBar`, `PhotographerProfileScreen` (`features/photographer_profile/`), `SettingsScreen`; core `AppAvatar`, `ProviderMark`/`providerMarkOf`, `ProviderTag`, `StatTile`/`StatTileRow`, `AppButton`, `AppChip`, `showAppSheet`, `showConfirmSheet`, `AsyncView`, `EmptyState`, `SectionHeader`, `StatusTimeline`, `ContactDial`, `ScreenCode`, `AppIcons`; #130's `VerdictPad`, `VerdictBadge`; `ScreenCodes.studioMembers 'S26.01'`, `inviteMember 'S26.02'`, `myStudio 'S26.03'`, `assignPhotographer 'S26.04'`, `requestPhotographerChange 'S26.05'` (already in `lib/core/screen_codes.dart`); `lib/app/router.dart`; `scripts/tools/build_ui_components.py` (`tile(anchor, name, api, use, real, skel)`), `docs/superpowers/specs/components/shared-components.md`.

## Global Constraints

- CLAUDE.md: rules only in `packages/domain` (no Firebase/Node imports, `purity.test.ts`); Functions thin, region `asia-southeast1`; `cloud_firestore`/`firebase_*` only in `lib/data/**`, `firebase_options.dart`, `main.dart`.
- Imports `package:photobooking/...` only; features import `core/core.dart`.
- Tokens via `AppColors`/`AppSpace`/`AppRadius`/`AppIcons`; 60‑30‑10; `tomato`/`brick` tokens only for the verdict icons and bars (#130).
- Strings in `lib/l10n/app_vi.arb` + `flutter gen-l10n`; exact keys and text in Contract §L10n.
- One `AppButton.primary` per screen (S26.02 and S26.03 have none, as the mock says); "Bỏ khỏi studio", "Rời studio", "Huỷ và hoàn 100%", "Từ chối đổi", "Trả việc" are red buttons inside confirmation sheets.
- Mock is the authority for layout and copy; specs for behaviour. Frames missing from the mock are added in Task 1 first.
- Conventions (`data-model/README.md`): opaque ids, UTC instants (ISO in the domain), integer VND, string enum codes.
- Money and contact rules (CLAUDE.md) stay: studio bookings are paid 100% to the studio's held account, released to the studio in two milestones (T11); 100% refunds come only from held money through `commitTransition`; contact channels unlock only after payment.
- Every assignment calls `ProviderOrderGate.acceptsOrders` for the studio and for the assignee (brief rule 5; spec V6 "studio chỉ giao việc cho thành viên đã xác minh"); refusal `not_accepting_orders`.
- Commits: Conventional Commits with `[#136]` in the subject; footer exactly `Co-Authored-By: TonyH <thanhngochoangbk@gmail.com>`.
- Flutter env (from `app_flutter/`): `source ../scripts/env.sh && export HOME="$PWD/../.home" && export PATH="$PWD/../.flutter/bin:$PATH"`. After changing a freezed class: `dart run build_runner build --delete-conflicting-outputs`.
- Flutter tests: `flutter test --no-pub --timeout 60s <file or folder>`, one folder at a time, never the whole suite in one command; bounded pumps, no endless animation or timer.
- Domain: `(cd packages/domain && npm test && npm run lint)`. Functions: `(cd app_flutter/firebase/functions && npm test && npm run build)`. Rules tests and Functions integration tests are written, not run.

## Decisions

1. **Relation documents.** Every relation gets a fresh id `{studioId}_{memberId}_{createdAtMs}` (spec §3.1 allows a suffix); history stays for cooldown and daily counts. "One open relation per pair" and "one active studio per member" are enforced by the domain inside the transaction: it reads `photographers/{memberId}` (`studioId`, `studioCooldownUntil`) and queries open relations of the pair; the member's `studioId` is the lock both studios write, so two concurrent accepts cannot both succeed.
2. **Public membership** comes from `photographers/{uid}.studioId` (public, server-written), not from `studio_members` (two parties only, spec §8). S03.01's members row queries `photographers where studioId == X order by studioJoinedAt limit 10`; the studio's `memberCount` gives "+n".
3. **Capacity.** `maxMembers = photographers/{studio}.businessVerified ? 30 : 3` (spec V5 via #135; absent field = 3). Count = `memberCount` + open invites; open invites ≤ 5. Join requests do not count until approved; approval checks the cap.
4. **Daily actions.** `studio_quota/{uid}` `{dayKey (VN), studioActions, memberActions}`, reset when `dayKey` changes. Studio ≤ 5 (invite, cancel invite, approve, remove); member ≤ 3 (request, cancel request, leave). Accept/decline of an invite and studio decline of a request are free.
5. **Who may be a member:** `providerType ∈ {individual, artist}` with `onboardingComplete`; not the studio itself; not a studio. A studio needs `providerType == studio` and `onboardingComplete`. Members need not be verified to join; they must be verified to be **assigned** (gate).
6. **Leaving and removal** are refused (`member_busy`) while the member has an open studio booking of that studio: `photographerId == studio`, `assigneeId == member`, status not in `{declined, expired, cancelled, completed, reviewed}` (covers #130's `shot`, `delivered`, `approved`, and disputes). The app shows the count from the studio's own booking list ("Còn {n} buổi chụp được giao").
7. **Provider type changes** (`setProviderType`): a studio becomes individual only with `memberCount == 0` and no open relation; a photographer becomes a studio only with no open relation; else `membership_conflict`.
8. **Studio bookings, through the one booking-draft builder (cross-plan review finding 21; #152's, since #129 did not build it).** Every order path reads the gate's new `orderProfile` (same single read as `acceptsOrders`) and passes `providerType` into #152's `BookingDraftInput` (new field `providerType: ProviderType | null`); `buildBookingDraft` then stores, when it is `studio`, `isStudio`, `assignStatus: 'unassigned'`, `assignDeadline = max(startAt − 24 h, now + 2 h)` capped at `startAt` (a booking made less than a day ahead gives the studio two hours; Needs the owner 1), `assignOverdue: false`, `assignments: []`, `changeRequest: null`, `studioFault: null`. Because the builder is shared, a quote booking (#139) or a collaborator-era booking (#151) of a studio gets the same fields; no order path builds them itself.
9. **Assignment model, ready for S27.** Booking: `assigneeId`, `assigneeKind: 'member'` (S27 adds `'collaborator'`), `assignedAt`, `assignments: [{assigneeId, assigneeKind, at, by, reason, late}]`. The domain never checks `studio_members` directly: it asks `StudioRoster.relationOf(studioId, uid) → 'member' | null` (S27 returns `'collaborator'` from its own collection) and `ProviderOrderGate.acceptsOrders(uid)`. Fields S27 (#151, plan `2026-10-07-s27-studio-recruiting.md`) adds without migration: `assigneeAccepted` on the booking (a member assignment counts as accepted when made) and `offerExpiresAt`, `acceptedAt`, `declinedAt` on assignment entries; the collaborator's fee never goes on the booking (the customer reads the whole booking document), it lives in S27's own collection. `assignBooking` keeps a single entry point that S27 extends with `{assigneeKind, agreedFee}`. Rules read the booking by `assigneeId` whatever the kind.
10. **`assignBooking`** (studio owner): booking `isStudio`, status `accepted` or `upcoming`, `now < startAt`; assignee ≠ current; relation not null; the studio passes `ProviderOrderGate` and the assignee passes #144's `orderBlocker(deps, {customerId: booking.customerId, providerId: assigneeId})` (provider gate + #144's `BlockGate`, customer ↔ assignee; `not_accepting_orders` / `blocked`; cross-plan review finding 22); the assignee's day is free (no availability record, or one holding this booking). Writes the booking, books the assignee's day `{state: 'booked', bookingId}`, frees the previous assignee's day when it holds this booking, answers a pending change request (`reassigned`), clears a returned-job mark and an `assign_overdue` fault (the mock "khối trở về trạng thái đã giao"). Reassigning after `assignDeadline` sets `studioFault: {kind: 'late_reassign'}` and `lateReassignCount + 1`. Assigning an `accepted` booking that starts within 24 h moves it to `upcoming` in the same write.
11. **Upcoming needs an assignee.** `decideTransition('upcoming')` and `accept` within 24 h refuse to reach `upcoming` for a studio booking without `assigneeId` (`accept` stays `accepted`; the sweep's `upcoming` is a `conflict`, swallowed as today).
12. **Customer's 100% cancel right** — `studioFaultOf(booking, now)` is non-null when `studioFault` is set (`assign_overdue`, `change_declined`, `change_expired`, `late_reassign`) or when the booking is unassigned past `assignDeadline`, and `now < startAt`. New transition action `cancel_studio_fault` (customer only, statuses `requested|accepted|upcoming`) → `cancelled`, refund 100% through `commitTransition`, `cancel.by = 'studio_fault'`, `cancel.reason = <fault kind>`. `commitTransition` also frees the assignee's day on any cancellation. Notices treat `studio_fault` like a customer cancellation (only the studio is told) plus the usual refund notice. `change_declined`/`change_expired`/`late_reassign` rights last until the start; `assign_overdue` ends when the studio assigns.
13. **One change request per booking:** customer, booking assigned, status `accepted|upcoming`, `changeRequest == null`, note ≤ 300; `respondBy = min(at + 6 h, startAt)`. Studio answers by reassigning (Decision 10) or `declineAssigneeChange` (reason 1–300 → `declined`, `changeDeclinedCount + 1`, fault `change_declined`). The sweep expires it (`expired`, same counter, fault `change_expired`).
14. **"Trả việc"** (`returnAssignment`, assignee only, before the start, reason ≤ 300): stores `assignmentReturned {at, reason}` and tells the studio; `assigneeId` stays until the studio reassigns (spec §5.2).
15. **Shoot and delivery.** The assignee may perform the action that moves the booking to `shot` (#130) and `complete`; `transitionBooking` maps the assignee to the photographer side for those actions only. Delivery callables already require `photographerId == caller`, so only the studio delivers (T9); the assignee's booking detail hides the S06.07 entry. #130's late-delivery handler increments `lateDeliveryCount` on the studio when `isStudio` (one line in Task 3, if #130 exposes the hook; else ledger).
16. **Chat.** `Chat.assigneeId: string | null` (added to #131's shared `chat round-trips every field` test; the booking's studio fields go into the shared `round-trips Booking through Firestore conversion` test; cross-plan review finding 41); `toFirestoreChat` writes `members: [customerId, photographerId, assigneeId?]`; `roleInChat` answers `'photographer'` for the assignee (they speak for the studio side); `syncBookingChat` copies the attached booking's `assigneeId` on every change (a reassign removes the old member, who loses access to the chat history). The booking chat id stays `chatIdFor(customerId, studioId)`.
17. **Rules for the assignee.** The assignee reads the booking and its `events`, and the customer's `private/contact` under the same unlock rule as the photographer (research §"Giao việc": the person meeting the customer needs the number). The customer does not get the assignee's own phone channels in this plan: the mock has no control for it (S05.02-studio shows only "Nhắn studio" and the studio's `ContactDial`); spec §5.7 part 2 is Deferred.
18. **Busy label in S26.04.** Availability is per day; the server callable `assignmentOptions` reads each member's day record and, when it holds a booking, that booking's `start`–`end` (Admin read) → "Bận 15:00–18:00"; an `off` day → "Bận cả ngày"; unverified → "Chưa xác minh" (disabled).
19. **Search in S26.02.** `photographers/{uid}.nameKey` = `lower(foldVietnamese(displayName))`, written by a new `onUserWrite` trigger (only when `displayName` changes and a photographer doc exists) and healed by `onPhotographerWrite` when missing (one `users` read). Callable `searchPhotographersToInvite({query})` does a prefix range on `nameKey` (≥ 2 characters, limit 20) and returns each row's state: `invitable`, `in_studio` (+ studio name), `cooldown` (+ date), `invited`, `member` (already ours).
20. **Sweeps** run inside `bookingClock` (every 15 min, spec §5.5 "dùng chung") as named steps at the end of its step list, each in its own try/catch, dependencies in the optional `BookingClockExtras.studio` (clock rule, restated in `2026-10-08-s04-reconciliation.md`), each idempotent: (a) `assignStatus == 'unassigned' && assignDeadline <= now + 24 h` → reminders `h48` (`now ≥ assignDeadline − 24 h`) and `h26` (`now ≥ assignDeadline − 2 h`) recorded in `assignRemindersSent`, and overdue (`now ≥ assignDeadline`, statuses `requested|accepted`) → `assignOverdue`, fault, `lateAssignCount + 1`, notices; (b) `changeRequest.status == 'pending' && respondBy <= now` → expired; (c) `studio_members status ∈ {invited, requested} && expiresAt <= now` → `expired`; `expiresAt <= now + 24 h && expiringNotifiedAt == null` (invites only) → `studio_invite_expiring`.
21. **Reviews (on #130's model).** A studio booking needs both blocks in one `submitReview` call; two documents in one transaction: `reviews/{bookingId}` (`subjectType 'photographer'`, `subjectId = photographerId = last assigneeId`, `viaStudioId`, `viaStudioName`) and `reviews/{bookingId}_studio` (`subjectType 'studio'`, `subjectId = photographerId = studioId`, `assigneeId`, `assigneeName`). Keeping `photographerId == subjectId` keeps #130's stats, `reviews (photographerId, createdAt)` lists and notifications working per subject without mixing. Studio brick reasons: `late_assignment`, `slow_response`, `price_changed`, `poor_assignment`, `other` (labels from the mock: "Báo thợ trễ", "Tư vấn chậm", "Đổi giá", "Giao thợ không hợp", "Khác"; mock wins over the spec's "Tư vấn/phản hồi chậm"). A studio booking without an assignee cannot be reviewed (`not_eligible`). `onReviewWrite` treats its path param as the review id (stats and dedupe key per document).
22. **Real-shoot post of a studio booking** keeps `photographerId = studioId` (the package belongs to the studio) and adds `assigneeId`; showing both tags on S02.02 is left to the feed owner (Deferred).
23. **Notifications through #138's hooks (cross-plan review finding 11).** #138 owns the 13 studio types (spec §7), their copy, category/tab (membership `booking`/`system`, assignment `booking`/`activity`), the critical list (`assign_overdue` only) and dedupe keys, in one table; this plan is their only emitter and adds no copy. `membershipNotices(change)` and `studioBookingNotices(before, after)` are pure "which hook to call" deciders; membership hooks are called by the callable adapter after commit, booking hooks by `onBookingWrite`, sweep hooks by the sweep. Hooks (signatures in Contract): `notifyStudioInvite`, `notifyStudioJoinRequest`, `notifyStudioInviteAccepted`, `notifyStudioJoinApproved`, `notifyStudioRemoved`, `notifyStudioInviteExpiring`, `notifyBookingAssigned`, `notifyBookingReassigned`, `notifyAssignReminder`, `notifyAssignOverdue`, `notifyChangeRequested`, `notifyChangeAnswered`, `notifyAssignmentReturned`. If #138 has not merged, create them and the catalogue rows exactly as S17's Contract defines them.
24. **Self-hosted parity:** `data-model/*.md` describe the target tables; the `services/api` migration is Deferred (no booking or review routes there; same as plans 10c, #133, #135).
25. **Error code names.** Daily caps here use `rate_limited` (#135's code, reused); other plans' daily caps use `limit_exceeded` — accepted as two names for two refusals (a quota per day vs a count limit), no code change (cross-plan review finding 42).
26. **Owner 2026-10-07: a studio takes one booking per free member per day.** A studio's day is bookable while its open bookings that day are fewer than its free members; it is no longer one booking per day for the whole studio (replaces Needs the owner 2).
   - **Capacity** (pure `studioDayCapacity`): `capacity(day) = freeMembers + assignedHere`, `load(day) = unassignedHere + assignedHere`, bookable iff `unassignedHere < freeMembers`. `freeMembers` = active members (`studioId == studio`, verified so they can be assigned) whose own `availability/{uid}/days/{day}` is empty (no `off`, no personal or other booking); `assignedHere` = this studio's open bookings that day already assigned (their member's day holds that booking); `unassignedHere` = this studio's open bookings that day without assignee (drafts included). A studio `off` day closes the studio that day.
   - **Holding.** A studio booking no longer writes `pending`/`booked` on the studio's own day; it is listed in `studio_day_load/{studioId}_{day}` `{studioId, day, unassignedIds: string[], assignedIds: string[], updatedAt}` (server-only), which holds the studio's capacity until assignment; `assignBooking` moves the id to `assignedIds` and books the member's day (`{state: 'booked', bookingId}`, Decision 10); cancel/decline/expire removes it and frees the member's day. The `createBookingDraft` path (studio branch through `orderProfile`) reads the load doc and the members' day docs inside its transaction (≤ 30 members) and refuses `day_taken` when `unassignedHere ≥ freeMembers`.
   - **Member personal bookings.** A member's own (individual) booking on a day the studio relies on reduces the studio's capacity; when it would leave the studio short (`unassignedHere ≥ freeMembers − 1` with this member counted free), the member's own booking is refused `day_taken` in the same transaction (it reads the studio's load doc of that day), so the studio never overbooks.
   - **What the app sees.** The server keeps a derived `availability/{studioId}/days/{day}` `{state: 'full'}` when `load ≥ capacity` (deleted when capacity returns), recomputed by `recomputeStudioDay(studioId, day)` after every studio booking change, every member day write (the existing `availability` trigger of #132 gains the call for members with a `studioId`) and every membership change. The S04.02 date step and the calendar read it like today (`DayState.full` → shown as "Hết chỗ", not selectable); #132's `nextFreeDate` treats it as a blocked day automatically.
   - **Collaborators (#151):** an `active` collaborator adds no capacity before a booking exists; a collaborator counts only once they have accepted an assignment offer (then that booking is in `assignedIds` and the collaborator's day is booked). #151's plan states this.

## Needs the owner

1. **Studio booking made less than 24 h ahead.** Default: the studio gets 2 hours to assign (Decision 8) instead of refusing such bookings.
2. (Decided by the owner 2026-10-07: one booking per free member per day, Decision 26.)
3. **Assignee's phone for the customer (spec §5.7).** Default: not offered (no control in the mock); the customer talks to the assignee in the booking chat; the assignee reads the customer's number after payment (Decision 17).
4. **Studio reason label.** Default: the mock's "Tư vấn chậm" for `slow_response`.

## Contract

### Data model

`studio_members/{studioId}_{memberId}_{createdAtMs}` (read: `studioId` or `memberId`; write: server): `studioId`, `memberId`, `status` (`invited` \| `requested` \| `active` \| `declined` \| `cancelled` \| `expired` \| `left` \| `removed`), `initiatedBy` (`studio` \| `member`), `createdAt`, `expiresAt` (= +7 days), `respondedAt?`, `joinedAt?`, `endedAt?`, `endedBy?` (`member` \| `studio` \| `system`), `expiringNotifiedAt?`, `studioName`, `studioAvatarUrl`, `memberName`, `memberAvatarUrl` (snapshots), `version`.

`studio_quota/{uid}` (read owner; write server): `dayKey`, `studioActions`, `memberActions`.

`studio_day_load/{studioId}_{day}` (server-only; Decision 26): `studioId`, `day`, `unassignedIds: string[]`, `assignedIds: string[]`, `updatedAt`. `availability/{studioId}/days/{day}` gains the server-written state `full` (Decision 26; the client still writes only `off`).

`photographers/{uid}` server fields: `studioId` (member), `studioJoinedAt`, `studioCooldownUntil`, `memberCount` (studio), `lateAssignCount`, `changeDeclinedCount`, `lateReassignCount`, `lateDeliveryCount`, `nameKey`.

`bookings/{id}` (studio bookings only; absent on individual ones): `isStudio: true`, `assigneeId: string | null`, `assigneeKind: 'member' | null`, `assignStatus: 'unassigned' | 'assigned'`, `assignDeadline`, `assignOverdue: bool`, `assignedAt | null`, `assignments: [{assigneeId, assigneeKind, at, by, reason | null, late: bool}]`, `assignRemindersSent: ('h48' | 'h26')[]`, `changeRequest: {at, note | null, respondBy, status: pending | reassigned | declined | expired, declineReason | null, answeredAt | null} | null`, `studioFault: {kind: assign_overdue | change_declined | change_expired | late_reassign, at} | null`, `assignmentReturned: {at, reason | null} | null`. `cancel.by` gains `studio_fault`. `chats/{id}.assigneeId`.

**S27-ready (no migration):** the assignee is identified by `assigneeId` plus a relation kind `assigneeKind` on the booking and on every `assignments[]` entry; this plan only writes `'member'`. A later collaborator assignment (S27, #151) writes `'collaborator'`, adds `assigneeAccepted` and per-entry offer timestamps, and keeps the fee off the booking; rules, chat membership, availability blocking, reviews ("last assignee") and the customer block read `assigneeId` without caring about the kind.

`reviews/{bookingId}` / `reviews/{bookingId}_studio`: #130 fields + `subjectType` (`photographer` \| `studio`), `subjectId`, `viaStudioId?`, `viaStudioName?`, `assigneeId?`, `assigneeName?`. `posts/{id}.assigneeId?` (real-shoot post of a studio booking).

### Domain (`packages/domain/src`)

```ts
// studio_membership.ts
export const INVITE_TTL_DAYS = 7, COOLDOWN_DAYS = 7, MAX_MEMBERS_UNVERIFIED = 3, MAX_MEMBERS_VERIFIED = 30,
  MAX_PENDING_INVITES = 5, STUDIO_DAILY_ACTIONS = 5, MEMBER_DAILY_ACTIONS = 3;
export const RELATION_STATUSES = ['invited', 'requested', 'active', 'declined', 'cancelled', 'expired', 'left', 'removed'] as const;
export type RelationStatus = (typeof RELATION_STATUSES)[number];
export const OPEN_RELATION_STATUSES: readonly RelationStatus[] = ['invited', 'requested', 'active'];
export interface StudioRelation { id: string; studioId: string; memberId: string; status: RelationStatus;
  initiatedBy: 'studio' | 'member'; createdAt: string; expiresAt: string; respondedAt: string | null; joinedAt: string | null;
  endedAt: string | null; endedBy: 'member' | 'studio' | 'system' | null; expiringNotifiedAt: string | null;
  studioName: string; studioAvatarUrl: string | null; memberName: string; memberAvatarUrl: string | null; version: number }
export interface StudioProfile { uid: string; providerType: ProviderType; onboardingComplete: boolean; businessVerified: boolean;
  memberCount: number; studioId: string | null; studioCooldownUntil: string | null; name: string; avatarUrl: string | null }
export interface DailyQuota { dayKey: string; studioActions: number; memberActions: number }
export function relationId(studioId: string, memberId: string, createdAt: Date): string;
export function maxMembers(studio: Pick<StudioProfile, 'businessVerified'>): number;
export function canJoinAsMember(p: StudioProfile): boolean;              // individual|artist + onboarded
export function inCooldown(p: Pick<StudioProfile, 'studioCooldownUntil'>, now: Date): boolean;
export function quotaLeft(q: DailyQuota | null, side: 'studio' | 'member', now: Date): number;
export function isOpenBookingStatus(s: string): boolean;                 // not declined|expired|cancelled|completed|reviewed
export function foldNameKey(displayName: string): string;               // lower(foldVietnamese(trim))

// studio_ports.ts
export interface StudioTx {
  getProfile(uid: string): Promise<StudioProfile | null>;              // photographers/{uid} + users/{uid} name/avatar
  getRelation(id: string): Promise<StudioRelation | null>;
  openRelationOf(studioId: string, memberId: string): Promise<StudioRelation | null>;
  countOpenInvites(studioId: string): Promise<number>;
  countOpenAssignments(studioId: string, memberId: string): Promise<number>;   // Decision 6
  getQuota(uid: string): Promise<DailyQuota | null>;
  putRelation(r: StudioRelation): void;
  setMemberStudio(memberId: string, patch: { studioId: string | null; studioJoinedAt: string | null; studioCooldownUntil?: string | null }): void;
  addMemberCount(studioId: string, delta: 1 | -1): void;
  putQuota(uid: string, q: DailyQuota): void;
}
export interface StudioStore {
  runTransaction<T>(fn: (tx: StudioTx) => Promise<T>): Promise<T>;
  dueRelations(now: Date, limit: number): Promise<StudioRelation[]>;   // invited|requested, expiresAt <= now + 24 h
}
export type AssigneeKind = 'member';                                    // S27 (#151) adds 'collaborator'
export interface StudioRoster {
  /** How `uid` may work for `studioId` today; null = may not be assigned. S27 returns 'collaborator' from its own collection. */
  relationOf(studioId: string, uid: string): Promise<AssigneeKind | null>;
  person(uid: string): Promise<{ name: string; avatarUrl: string | null } | null>;
}
export interface StudioDeps { readonly studios: StudioStore; readonly clock: Clock; readonly ids: IdGenerator }

// studio_use_cases.ts — each returns {before, after} relations for notifications
export function inviteMember(deps: StudioDeps, studioId: string, raw: unknown /* {memberId} */): Promise<RelationChange>;
export function cancelInvite(deps: StudioDeps, studioId: string, raw: unknown /* {relationId} */): Promise<RelationChange>;
export function requestToJoin(deps: StudioDeps, memberId: string, raw: unknown /* {studioId} */): Promise<RelationChange>;
export function cancelJoinRequest(deps: StudioDeps, memberId: string, raw: unknown /* {relationId} */): Promise<RelationChange>;
export function respondInvite(deps: StudioDeps, memberId: string, raw: unknown /* {relationId, accept} */): Promise<RelationChange>;
export function respondJoinRequest(deps: StudioDeps, studioId: string, raw: unknown /* {relationId, accept} */): Promise<RelationChange>;
export function leaveStudio(deps: StudioDeps, memberId: string): Promise<RelationChange>;
export function removeMember(deps: StudioDeps, studioId: string, raw: unknown /* {memberId} */): Promise<RelationChange>;
export function runMembershipSweeps(deps: StudioDeps): Promise<{ expired: RelationChange[]; expiring: StudioRelation[] }>;
export interface RelationChange { readonly before: StudioRelation | null; readonly after: StudioRelation }
export type MembershipNotice = 'invite' | 'join_request' | 'invite_accepted' | 'join_approved' | 'removed';
export function membershipNotices(c: RelationChange): MembershipNotice[];           // pure decider; the adapter calls #138's hooks

// studio_assignment.ts (uses BookingDeps + roster)
export interface StudioBookingDeps extends BookingDeps { readonly roster: StudioRoster }
export type StudioFaultKind = 'assign_overdue' | 'change_declined' | 'change_expired' | 'late_reassign';
export const STUDIO_ASSIGN_LEAD_HOURS = 24, STUDIO_LATE_BOOKING_GRACE_HOURS = 2, CHANGE_RESPOND_HOURS = 6,
  ASSIGN_REMINDER_HOURS = [48, 26] as const;
export function assignDeadlineFor(startAt: Date, now: Date): Date;      // Decision 8
export function studioFaultOf(b: Booking, now: Date): StudioFaultKind | null;
export function assignBooking(deps: StudioBookingDeps, callerId: string, raw: unknown /* {bookingId, assigneeId} */): Promise<Booking>;
export function assignmentOptions(deps: StudioBookingDeps & { availability: MemberDayReader }, callerId: string,
  raw: unknown /* {bookingId} */): Promise<AssignmentOption[]>;
export interface AssignmentOption { uid: string; name: string; avatarUrl: string | null; tomatoPct: number | null; reviewCount: number;
  state: 'free' | 'busy' | 'off' | 'unverified' | 'current'; busyStart: string | null; busyEnd: string | null }
export interface MemberDayReader { members(studioId: string): Promise<string[]>;                         // active member uids
  day(uid: string, day: string): Promise<{ state: 'off' | 'booked' | 'pending'; start: string | null; end: string | null } | null>;
  stats(uid: string): Promise<{ tomatoPct: number | null; reviewCount: number }> }
export function requestAssigneeChange(deps: StudioBookingDeps, customerId: string, raw: unknown /* {bookingId, note?} */): Promise<Booking>;
export function declineAssigneeChange(deps: StudioBookingDeps, studioId: string, raw: unknown /* {bookingId, reason} */): Promise<Booking>;
export function returnAssignment(deps: StudioBookingDeps, assigneeId: string, raw: unknown /* {bookingId, reason?} */): Promise<Booking>;
export function runStudioBookingSweeps(deps: StudioBookingDeps): Promise<{ overdue: number; reminders: number; changesExpired: number }>;
export type StudioNotice = 'assigned' | 'reassigned' | 'change_requested' | 'change_answered' | 'assignment_returned';
export function studioBookingNotices(before: Booking | null, after: Booking | null): StudioNotice[];   // pure decider, used by onBookingWrite → #138's hooks
// consumed from #138 (packages/domain/src/notification_hooks.ts; copy, category/tab, critical and dedupe keys are #138's):
// notifyStudioInvite(deps, {photographerId, studioId, inviteId}); notifyStudioJoinRequest(deps, {studioId, photographerId, requestId});
// notifyStudioInviteAccepted(deps, {studioId, photographerId, inviteId}); notifyStudioJoinApproved(deps, {photographerId, studioId, requestId});
// notifyStudioRemoved(deps, {photographerId, studioId, membershipId}); notifyStudioInviteExpiring(deps, {photographerId, studioId, inviteId});
// notifyBookingAssigned(deps, {bookingId, customerId, studioId, assigneeId, day, start});
// notifyBookingReassigned(deps, {bookingId, customerId, studioId, oldAssigneeId, newAssigneeId, day, start});
// notifyAssignReminder(deps, {bookingId, studioId, hours: 48 | 26, day, start}); notifyAssignOverdue(deps, {bookingId, customerId, studioId, day, start});
// notifyChangeRequested(deps, {bookingId, customerId, studioId, day, respondBy /* 'HH:mm dd/MM' */});
// notifyChangeAnswered(deps, {bookingId, customerId, studioId, outcome: 'reassigned' | 'declined' | 'expired'});
// notifyAssignmentReturned(deps, {bookingId, studioId, assigneeId, day, start});
// (every hook: Promise<NotifyResult | NotifyResult[]>; relation ids are the studio_members doc ids)
// studio_capacity.ts (Decision 26, owner 2026-10-07)
export interface StudioDayFacts { readonly studioOff: boolean; readonly memberDays: readonly { uid: string; verified: boolean; free: boolean }[];
  readonly unassignedIds: readonly string[]; readonly assignedIds: readonly string[] }
export function studioDayCapacity(f: StudioDayFacts): { freeMembers: number; capacity: number; load: number; bookable: boolean; full: boolean };
//   freeMembers = verified members with free === true; capacity = freeMembers + assignedIds.length; load = unassigned + assigned;
//   bookable = !studioOff && unassignedIds.length < freeMembers; full = studioOff || load >= capacity
export function memberDayReleasable(f: StudioDayFacts, memberUid: string): boolean; // false when the studio needs this member that day
// StudioBookingTx gains getStudioDayLoad(studioId, day) / setStudioDayLoad(load) / getMemberDays(studioId, day): Promise<StudioDayFacts['memberDays']>
// booking.ts: Booking gains the studio fields of the data model; BookingCancel.by gains 'studio_fault'
// booking_machine.ts: TransitionAction gains 'cancel_studio_fault'; upcoming/accept guards (Decision 11)
// transition_booking.ts: assignee → photographer side for 'complete' and #130's shot action (Decision 15)
// commit_transition.ts: frees the assignee's day on cancel/decline/expire
// create_booking.ts: #152's BookingDraftInput gains providerType and buildBookingDraft the studio fields (Decision 8); booking_ports.ts:
//   ProviderOrderGate.orderProfile(photographerId): Promise<{ acceptsOrders: boolean; providerType: ProviderType } | null>
//   BookingTx gains incrementStudioCounter (the memory and Firestore stores implement it on the booking transaction):
export interface StudioBookingTx extends BookingTx { incrementStudioCounter(studioId: string,
  field: 'lateAssignCount' | 'changeDeclinedCount' | 'lateReassignCount' | 'lateDeliveryCount'): void }
// chat.ts: Chat.assigneeId; roleInChat; booking_chat_sync.ts copies assigneeId
// set_provider_type.ts + provider_ports.ts: ProviderTx.countOpenRelations(uid), ProviderProfile.memberCount (Decision 7)
// errors.ts: 'membership_conflict', 'cooldown', 'member_busy', 'studio_full', 'rate_limited' (rate_limited may already exist from #135)
// review.ts / submit_review.ts on #130: STUDIO_BRICK_REASONS; validateReviewInput(raw, callerId, prefixes, { studio: boolean })
//   returns #130's input plus `studio: VerdictBlock | null`; submitReview writes one or two documents (Decision 21)
```

Refusals: wrong caller → `permission_denied`; missing doc → `not_found`; not studio/member type → `invalid_argument`; member active elsewhere or type change blocked → `membership_conflict`; within 7 days of leaving → `cooldown`; open studio bookings → `member_busy`; cap or 5 open invites → `studio_full`; daily limit → `rate_limited`; open relation of the pair, already answered, change request used → `conflict`; expired invite answered → `deadline_passed`; assignee day taken → `day_taken`; assignee or studio closed → `not_accepting_orders`; after start or wrong status → `not_eligible`.

### Callables (`asia-southeast1`, `CALLABLE_OPTIONS`)

| Name | Input → output | Caller |
|---|---|---|
| `inviteMember` | `{memberId}` → `{relationId}` | studio |
| `cancelInvite` | `{relationId}` → `{}` | studio |
| `requestToJoin` | `{studioId}` → `{relationId}` | photographer |
| `cancelJoinRequest` | `{relationId}` → `{}` | photographer |
| `respondInvite` | `{relationId, accept: bool}` → `{status}` | invited photographer |
| `respondJoinRequest` | `{relationId, accept: bool}` → `{status}` | studio |
| `leaveStudio` | `{}` → `{}` | member |
| `removeMember` | `{memberId}` → `{}` | studio |
| `searchPhotographersToInvite` | `{query}` → `{rows: [{uid, name, avatarUrl, verified, tomatoPct, areaLabel, state, studioName?, availableFrom?}]}` | studio |
| `assignmentOptions` | `{bookingId}` → `{deadline, options: AssignmentOption[]}` | studio |
| `assignBooking` | `{bookingId, assigneeId}` → `Booking` | studio |
| `requestAssigneeChange` | `{bookingId, note?}` → `Booking` | customer |
| `declineAssigneeChange` | `{bookingId, reason}` → `Booking` | studio |
| `returnAssignment` | `{bookingId, reason?}` → `Booking` | assignee |

`transitionBooking` accepts `action: 'cancel_studio_fault'`. `submitReview` accepts `studio: {verdict, hits, reasons, text}` (#130 field names). `TRANSPORT_CODE`: `membership_conflict`, `cooldown`, `member_busy` → `failed-precondition`; `studio_full`, `rate_limited` → `resource-exhausted`.

### Dart (`app_flutter/lib`)

```dart
// lib/data/studio/studio_relation.dart
enum RelationStatus { invited, requested, active, declined, cancelled, expired, left, removed }
@immutable class StudioRelation { id, studioId, memberId, status, initiatedBy, createdAt, expiresAt, joinedAt?, studioName, studioAvatarUrl?, memberName, memberAvatarUrl? }
@immutable class StudioQuota { final int left; final int max; }               // from studio_quota + side
@immutable class InviteCandidate { uid, name, avatarUrl?, verified, tomatoPct?, areaLabel?, InviteState state, studioName?, DateTime? availableFrom }
enum InviteState { invitable, inStudio, cooldown, invited, member }
@immutable class AssignmentOption { uid, name, avatarUrl?, tomatoPct?, AssignState state, String? busyStart, String? busyEnd }
enum AssignState { free, busy, off, unverified, current }
// lib/data/studio/studio_repository.dart
class StudioError implements Exception { const StudioError(this.code); final String code; }
abstract class StudioRepository {
  Stream<List<StudioRelation>> watchStudioRelations(String studioId);   // invited|requested|active, newest first
  Stream<List<StudioRelation>> watchMemberRelations(String memberId);   // invited|requested|active
  Stream<StudioQuota> watchQuota(String uid, {required bool studio});
  Future<String> invite(String memberId);
  Future<void> cancelInvite(String relationId);
  Future<String> requestToJoin(String studioId);
  Future<void> cancelJoinRequest(String relationId);
  Future<void> respondInvite(String relationId, {required bool accept});
  Future<void> respondJoinRequest(String relationId, {required bool accept});
  Future<void> leave();
  Future<void> remove(String memberId);
  Future<List<InviteCandidate>> search(String query);
  Future<({DateTime deadline, List<AssignmentOption> options})> assignmentOptions(String bookingId);
}
class FakeStudioRepository implements StudioRepository { … }
// lib/data/studio/firestore_studio_repository.dart, studio_providers.dart:
final studioRepositoryProvider = Provider<StudioRepository>(…);
final myStudioRelationsProvider = StreamProvider.autoDispose<List<StudioRelation>>(…);   // studio side
final myMemberRelationsProvider = StreamProvider.autoDispose<List<StudioRelation>>(…);   // member side
final studioQuotaProvider = StreamProvider.autoDispose.family<StudioQuota, bool>(…);
final studioMembersProvider = FutureProvider.autoDispose.family<List<PhotographerSummary>, String>(…); // public row
// assignee's bookings: #134's assignedBookingsProvider / myWorkBookingsProvider (lib/data/booking/booking_providers.dart), reused, not redefined (cross-plan review finding 45)
// lib/data/booking/studio_booking.dart
@freezed class StudioBookingInfo { assigneeId?, assigneeKind?, assignStatus, assignDeadline, assignOverdue, assignedAt?,
  List<StudioAssignment> assignments, StudioChangeRequest? changeRequest, StudioFault? studioFault, DateTime? returnedAt, String? returnReason }
// Booking gains `StudioBookingInfo? studio` (null for individual bookings); BookingAction gains cancelStudioFault ('cancel_studio_fault')
// BookingRepository gains: assign(bookingId, assigneeId), requestChange(bookingId, {String? note}), declineChange(bookingId, reason), returnAssignment(bookingId, {String? reason})
// PhotographerRepository gains membersOf(String studioId, {int limit = 10}); PhotographerSummary gains studioId, memberCount
// ReviewRepository.submit gains `StudioReviewDraft? studio` ({verdict, hits, reasons, text}); Review gains subjectType, viaStudioName, assigneeName
// core widgets: MemberRow (avatar, name, meta line, trailing), MemberStrip (S03.01 .mems: up to 4 + "+n"), AssigneeCard (S05.02 block)
```

Routes: `/studio/members` (`StudioMembersScreen`, S26.01), `/me/studio` (`MyStudioScreen`, S26.03). Sheets: `showInviteMemberSheet` (S26.02), `showAssignSheet(bookingId)` (S26.04), `showChangeRequestSheet(bookingId)` (S26.05), `showStudioFaultCancelSheet`, `showReturnJobSheet`, `showDeclineChangeSheet`.

### Notifications

No copy here: #138's catalogue holds the 13 studio types with one copy set, targets (`/me/studio`, `/studio/members`, `/b/{id}`) and dedupe keys (Decision 23; the hooks are listed in Contract → Domain). The copy this plan drafted before the cross-plan review was dropped in favour of #138's table.

### L10n (`app_vi.arb`, exact text)

S26.01: `studioMembersTitle` "Thành viên"; `studioMembersRulesA11y` "Quy định thành viên"; `studioMembersQuota` "{n}/{max} thợ · còn {k} thao tác hôm nay"; `studioMemberAssigned` "{m} việc đang giao"; `studioMemberNoWork` "chưa có việc"; `studioMemberOptions` "Tuỳ chọn cho {name}"; `studioPendingTitle` "Đang chờ"; `studioPendingCount` "{n} · tối đa 5 lời mời"; `studioInviteSentDays` "Lời mời đã gửi · Hết hạn sau {n} ngày"; `studioInviteSentToday` "Lời mời đã gửi · Hết hạn trong hôm nay"; `studioJoinRequestedAgo` "Xin gia nhập · {ago}"; `studioCancelInvite` "Huỷ"; `studioDecline` "Từ chối"; `studioApprove` "Duyệt"; `studioInviteAction` "Mời thợ"; `studioMembersEmpty` "Chưa có thành viên"; `studioMembersEmptyBody` "Mời thợ ảnh bạn tin tưởng; họ nhận lời là vào studio."; `studioRemoveMember` "Bỏ khỏi studio"; `studioRemoveTitle` "Bỏ {name} khỏi studio?"; `studioRemoveBody` "{name} sẽ không nhận việc của studio nữa và 7 ngày sau mới vào được studio khác."; `studioRemoveKeep` "Giữ lại"; `studioBusyTitle` "Còn {n} buổi chụp được giao"; `studioRemoveBusyBody` "Giao các buổi này cho người khác hoặc chờ chụp xong rồi bỏ."; `studioFullUnverified` "Đã đủ 3 thợ. Xác minh doanh nghiệp để nhận tới 30 thợ."; `studioFullVerifyAction` "Xác minh doanh nghiệp"; `studioQuotaOut` "Hết thao tác hôm nay. Thử lại ngày mai."; `studioRulesTitle` "Quy định thành viên"; `studioRule1` "Vào studio cần hai bên đồng ý: studio mời và thợ nhận, hoặc thợ xin và studio duyệt."; `studioRule2` "Lời mời hết hạn sau 7 ngày, tối đa 5 lời mời chờ."; `studioRule3` "Mỗi thợ ở tối đa một studio. Rời hoặc bị bỏ thì 7 ngày sau mới vào được studio khác."; `studioRule4` "Tối đa 3 thợ khi studio chưa xác minh doanh nghiệp, 30 khi đã xác minh; tối đa 5 thao tác thành viên mỗi ngày."; `studioRule5` "Không bỏ được thành viên còn buổi chụp được giao chưa xong.".
S26.02: `studioInviteTitle` "Mời thợ"; `studioInviteSearch` "Tìm thợ theo tên"; `studioInviteRowAction` "Mời"; `studioInviteInStudio` "Đang ở {studio}"; `studioInviteCooldown` "Mời được từ {date}"; `studioInviteInvited` "Đã mời"; `studioInviteMember` "Đã là thành viên"; `studioInviteFootnote` "Lời mời hết hạn sau 7 ngày · tối đa 5 lời mời chờ"; `studioInviteFullPending` "Đã có 5 lời mời chờ"; `studioInviteFullMembers` "Studio đã đủ {max} thợ"; `studioInviteNoResults` "Không tìm thấy thợ tên này"; `studioInviteDone` "Đã gửi lời mời tới {name}".
S26.03: `myStudioTitle` "Studio của tôi"; `myStudioSince` "Thành viên từ {month} · {m} việc được giao"; `myStudioView` "Xem studio"; `myStudioJobs` "Việc studio giao"; `myStudioAssignedBadge` "Đã giao"; `myStudioLeave` "Rời studio"; `myStudioInvites` "Lời mời"; `myStudioAccept` "Nhận"; `myStudioDecline` "Từ chối"; `myStudioInviteBlocked` "Bạn đang ở {studio}"; `myStudioCooldownNote` "Rời hoặc bị bỏ khỏi studio thì 7 ngày sau mới vào được studio khác."; `myStudioNone` "Bạn chưa ở studio nào"; `myStudioNoneBody` "Studio mời bạn, hoặc bạn xin gia nhập từ hồ sơ studio."; `myStudioRequestPending` "Đã xin gia nhập {studio} · chờ duyệt"; `myStudioRequestCancel` "Huỷ"; `myStudioLeaveTitle` "Rời {studio}?"; `myStudioLeaveBody` "7 ngày sau bạn mới vào được studio khác, kể cả {studio}."; `myStudioLeaveKeep` "Ở lại"; `myStudioLeaveBusyBody` "Chụp xong hoặc nhờ studio giao người khác rồi rời.".
S26.04: `assignTitle` "Giao thợ"; `assignSummary` "{service} · {day} · {start}–{end}"; `assignDeadline` "Hạn giao thợ: {deadline} (còn {left})"; `assignDeadlinePassed` "Đã quá hạn giao thợ ({deadline})"; `assignLeftDays` "{n} ngày"; `assignLeftHours` "{n} giờ"; `assignFree` "Rảnh"; `assignBusy` "Bận {start}–{end}"; `assignBusyAllDay` "Bận cả ngày"; `assignUnverified` "Chưa xác minh"; `assignCurrent` "Đang giao"; `assignNote` "Khách được báo ngay; {name} vào nhóm chat của buổi chụp."; `assignLateWarning` "Còn dưới 24 giờ: đổi thợ lúc này thì khách được huỷ và hoàn 100%."; `assignAction` "Giao cho {name}"; `assignNoMembers` "Studio chưa có thành viên nào để giao.".
S26.05: `changeTitle` "Xin đổi thợ chụp"; `changeCurrent` "Thợ hiện tại"; `changeReasonLabel` "Lý do (tuỳ chọn)"; `changeNoteRespond` "Studio trả lời trong 6 giờ."; `changeNoteRefund` "Nếu studio từ chối hoặc không trả lời, bạn được huỷ và hoàn 100%."; `changeOnce` "Bạn chỉ xin đổi được 1 lần."; `changeSend` "Gửi yêu cầu đổi"; `changeSent` "Đã gửi yêu cầu đổi thợ".
S05.02: `assigneeSection` "Thợ chụp cho bạn"; `assigneeAssignedOn` "Giao {date}"; `assigneeWaiting` "Studio sẽ báo thợ chụp trước {deadline}"; `assigneeMeta` "{shoots} buổi · thợ của {studio}"; `assigneeViewProfile` "Xem hồ sơ"; `assigneeChange` "Xin đổi thợ (1 lần)"; `assigneeChangePending` "Đã xin đổi · chờ studio"; `assigneeOverdueLabel` "Quá hạn"; `assigneeOverdueTitle` "Studio chưa báo thợ chụp đúng hạn (trước {deadline})"; `assigneeOverdueBody` "Bạn có thể chờ thêm hoặc huỷ và được hoàn 100%."; `assigneeCancelFull` "Huỷ và hoàn 100%"; `assigneeReminded` "Đã nhắc {studio} lúc {first} và {second}."; `assigneeChangeDeclinedTitle` "Studio không đổi thợ chụp"; `assigneeChangeDeclinedBody` "Lý do: {reason}. Bạn giữ thợ hiện tại hoặc huỷ và được hoàn 100%."; `assigneeChangeExpiredTitle` "Studio chưa trả lời yêu cầu đổi thợ"; `assigneeChangeExpiredBody` "Bạn giữ thợ hiện tại hoặc huỷ và được hoàn 100%."; `assigneeLateReassignTitle` "Studio đã đổi thợ khi còn dưới 24 giờ"; `assigneeLateReassignBody` "Bạn có thể huỷ và được hoàn 100%."; `timelineAssigned` "Đã giao thợ chụp"; `timelineAssignedBody` "{name} đã vào nhóm chat của buổi chụp"; `timelineAwaitAssign` "Chờ studio giao thợ chụp"; `timelineAwaitAssignBody` "Quá hạn từ {deadline}"; `detailMessageStudio` "Nhắn studio"; `cancelStudioFaultTitle` "Huỷ và hoàn 100%?"; `cancelStudioFaultLine` "Hoàn 100% số đã trả"; `cancelStudioFaultBody` "Studio chưa giữ đúng cam kết về thợ chụp nên bạn được hoàn toàn bộ số đã trả."; `cancelStudioFaultConfirm` "Huỷ và hoàn 100%"; `cancelStudioFaultKeep` "Giữ lịch".
S06.01: `workAssignAction` "Giao thợ"; `workAssignedTo` "Thợ: {name}"; `workAssignOverdue` "Quá hạn giao thợ"; `workChangeRequested` "Khách xin đổi thợ · trả lời trước {time}"; `workChangeDecline` "Từ chối đổi"; `changeDeclineTitle` "Từ chối đổi thợ?"; `changeDeclineReason` "Lý do (bắt buộc)"; `changeDeclineBody` "Khách sẽ thấy lý do và được huỷ, hoàn 100% nếu không muốn giữ thợ hiện tại."; `changeDeclineConfirm` "Từ chối đổi"; `changeDeclineKeep` "Quay lại"; `workAssignedBy` "Giao bởi {studio}"; `workReturnJob` "Trả việc"; `returnJobTitle` "Trả lại buổi chụp này?"; `returnJobBody` "{studio} được báo để giao người khác. Bạn vẫn là thợ của buổi này tới khi studio giao lại."; `returnJobReason` "Lý do (tuỳ chọn)"; `returnJobConfirm` "Trả việc"; `returnJobKeep` "Giữ việc"; `workReturned` "Đã trả việc · chờ studio giao lại".
S03.01: `profileMembersTile` "thành viên"; `profileYearsValue` "{n} năm"; `profileYearsTile` "hoạt động"; `profileMembersTitle` "Thành viên"; `profileMembersA11y` "Thành viên {studio}"; `profileMoreMembersA11y` "và {n} thành viên khác"; `profileJoinStudio` "Xin gia nhập"; `profileJoinRequested` "Đã xin gia nhập"; `profileJoinSent` "Đã gửi yêu cầu tới {studio}"; `profileJoinCooldown` "Bạn vào được studio từ {date}"; `profileMemberOf` "Thành viên của {studio}".
S09.02 (rows of #148, Decision 12 order; cross-plan review finding 32): `settingsStudioMembers` "Thành viên studio" and `settingsMyStudio` "Studio của tôi" are #148's keys (add only if absent); `settingsStudioMembersBody` stays #148's text; this plan's status subtitles are new keys `settingsStudioMembersQuota` "{n}/{max} thợ" and `settingsMyStudioNone` "Chưa ở studio nào".
S05.05 and reviews: `reviewCardAssignee` "{day} · thợ {name}"; `reviewBlockAssignee` "Thợ {name}"; `reviewBlockAssigneeNote` "Tính cho hồ sơ thợ"; `reviewBlockStudioNote` "Tính cho studio"; `reviewNoteForAssignee` "Nhận xét cho thợ"; `reviewNoteForStudio` "Nhận xét cho studio"; `reviewSubmitTwo` "Gửi 2 đánh giá"; `reviewMissingAssignee` "Còn thiếu đánh giá cho thợ"; `reviewMissingStudio` "Còn thiếu đánh giá cho studio"; `reviewStudioReason_late_assignment` "Báo thợ trễ"; `reviewStudioReason_slow_response` "Tư vấn chậm"; `reviewStudioReason_price_changed` "Đổi giá"; `reviewStudioReason_poor_assignment` "Giao thợ không hợp"; `reviewStudioReason_other` "Khác"; `reviewA11yTomatoFor` "Ném cà chua cho {who}, {n} trên 10"; `reviewA11yBrickFor` "Ném gạch cho {who}, {n} trên 10"; `reviewShotBy` "Chụp bởi {name}"; `reviewViaStudio` "Qua {studio}".
Errors: `studioErr_membership_conflict` "Thợ này đang ở một studio khác."; `studioErr_cooldown` "Chưa đủ 7 ngày kể từ lần rời studio."; `studioErr_member_busy` "Còn buổi chụp được giao chưa xong."; `studioErr_studio_full` "Studio đã đủ số thợ hoặc đủ 5 lời mời chờ."; `studioErr_rate_limited` "Hết thao tác hôm nay. Thử lại ngày mai."; `studioErr_not_accepting_orders` "Thợ này chưa xác minh nên chưa giao việc được."; `studioErr_day_taken` "Thợ này đã bận ngày này."; `studioErr_conflict` "Yêu cầu đã được xử lý trước đó."; `studioErr_generic` "Chưa thực hiện được. Thử lại.".

### Rules and indexes

```
match /studio_members/{id} {
  allow read: if signedIn() && (resource.data.studioId == request.auth.uid || resource.data.memberId == request.auth.uid);
  allow write: if false;
}
match /studio_quota/{uid} { allow read: if isOwner(uid); allow write: if false; }
match /studio_day_load/{id} { allow read, write: if false; }
// availability/{uid}/days/{day}: the client may still write only state 'off'; 'full' is server-written (Decision 26)
// bookings/{id} read: + || resource.data.get('assigneeId', null) == request.auth.uid
// bookings/{id}/events read and private/contact read: + the same assignee clause (contact keeps isBookingContactUnlocked)
// photographerServerFieldsUntouched(): + 'studioId','studioJoinedAt','studioCooldownUntil','memberCount','lateAssignCount',
//   'changeDeclinedCount','lateReassignCount','lateDeliveryCount','nameKey'
```
Indexes (COLLECTION): `bookings (assigneeId ASC, createdAt DESC)`; `bookings (photographerId ASC, assigneeId ASC, status ASC)`; `bookings (assignStatus ASC, assignDeadline ASC)`; `bookings (changeRequest.status ASC, changeRequest.respondBy ASC)`; `studio_members (studioId ASC, status ASC, createdAt DESC)`; `studio_members (memberId ASC, status ASC, createdAt DESC)`; `studio_members (studioId ASC, memberId ASC, status ASC)`; `studio_members (status ASC, expiresAt ASC)`; `photographers (studioId ASC, studioJoinedAt ASC)`. `photographers.nameKey` range uses the automatic single-field index.

## Review Focus

1. **Two accepts at once** — a photographer with two invites accepts both in parallel (or a studio approves while another accepts): exactly one becomes `active`, the other answers `membership_conflict`; `memberCount` and `studioId` agree. Pinned in Task 2 ("parallel accepts…") and the Task 5 integration test (written).
2. **Assignment that cannot happen** — a member busy that day, unverified, removed, or a booking after its start: refused without writing anything; a reassign frees the old member's day and books the new one in the same transaction; the old member loses the chat and the booking (rules). Pinned in Task 3 and Task 5 rules tests ("a former assignee cannot read the booking or the chat").
3. **The 100% refund right** — appears when overdue (even before the sweep runs), disappears when the studio then assigns; stays after a declined/expired change or a late reassign; refunds only held money, once (`cancel_studio_fault` twice → `conflict`). Pinned in Task 3.
4. **Clock boundaries** — the daily limit resets at 00:00 Vietnam time (17:00 UTC), the 7-day cooldown and 7-day invite expiry are exact, reminders fire once at 48 h and 26 h. Pinned in Task 2 and Task 3 sweep tests.
5. **Reviews do not mix** — a studio booking needs both blocks; the member's % only counts the member review, the studio's only the studio review; the reviewed member is the last assignee. Pinned in Task 4.

## Chi phí Google

Unit prices from `2026-10-07-google-cloud-costs.md`: Firestore nam5 upper bound $0.06/100K reads, $0.18/100K writes (**Singapore chưa xác nhận**); no paid API. **Functions (one rule for every plan, cost spec §12):** at (b) new invocations and CPU fit the free tier (2M invocations, 180,000 vCPU-s, 360,000 GiB-s per month) → $0; at (c) the app already uses the free tier up (§12 (c): 2.5M invocations, ~500K vCPU-s), so this plan's Functions work is charged at Tier 2: $0.40/M invocations, $0.0000336/vCPU-s, $0.0000035/GiB-s. Volumes: (b) 1,000 MAU → ~10 studios, ~90 studio bookings/month (30% of 300), ~2,000 studio-profile views; (c) 10,000 MAU → ~100 studios, ~900 studio bookings/month, ~20,000 studio-profile views, ~50,000 member-profile views.

| User action | Reads | Writes | Notes |
|---|---|---|---|
| Open S26.01 | listeners: relations (≤ 10 docs), quota (1), studio bookings (already open in Công việc) | 0 | listener: answers arrive from the other side |
| Invite / approve / remove / leave | 5–7 (profiles, open relation, counts, quota) | 3–4 (relation, member, studio count, quota) + 1 notification (2 writes) | |
| S26.02 search | 1 query ≤ 20 + ≤ 20 users + ≤ 5 studios ≈ 45 | 0 | `get` via callable; ≥ 2 characters |
| Open S26.03 | listeners: own relations (≤ 5), assigned bookings (≤ 20) | 0 | |
| S26.04 open | members ≤ 30 → typical 4 members × 3 ≈ 13 (worst 91) | 0 | callable `get` |
| Assign / reassign | 6 | 3–4 (booking, 1–2 availability days) + trigger chat write + 2–3 notifications | `onBookingWrite` re-runs (existing) |
| Change request / decline / return | 3 | 1 + 1 notification | |
| S03.01 studio profile | +≤ 10 photographers + ≤ 10 users = +20 | 0 | `get`, limit 10 |
| S03.01 member profile | +1 (studio user doc) | 0 | |
| S05.02 studio booking | +2 (assignee user + photographer) | 0 | |
| S05.05 studio review | as #130 + 1 | +1 review, +2 stats | `onReviewWrite` runs twice |
| Studio booking draft (Decision 26) | + load doc 1 + members' day docs ≤ 30 (typ. 3–5) | +1 load doc | inside the draft transaction |
| Capacity recompute (studio booking change, member day write) | ~load 1 + member days ≤ 30 | 0–1 (`full` day doc) | trigger work, (c) ~10K runs/month |

- **New callables:** 14 (+ `transitionBooking` action, `submitReview` field). Calls: (b) ~1,000/month ($0), (c) ~10,000/month (Functions rule: ≈ 2,000 vCPU-s ≈ $0.07); 256 MiB, 10 s. Capacity recompute (Decision 26) runs inside existing triggers: (c) ~10K extra runs × ~0.1 vCPU-s ≈ $0.03, ~100K reads ≈ $0.06.
- **New trigger:** `onUserWrite` (`users/{uid}`): every user doc write, (b) ~3,000/month, (c) ~30,000/month; writes only when a photographer's display name changes (rare). `onPhotographerWrite` heal adds ≤ 1 read once per photographer.
- **New scheduled jobs:** none. `bookingClock` (15 min, 2,880 runs/month) gains three queries (unassigned studio bookings, pending change requests, expiring relations; empty = 1 read each) → +8,640 reads/month ≈ $0.005, plus the matched documents (tens per run at (c)).
- **Storage:** none. **Paid APIs:** none (no SMS, Maps, Vision, KMS).
- **Reads/writes per month:** (b) profiles 40K + members/search/options ~10K + sweeps 9K ≈ 60K reads ($0.04), writes ~3K ($0.005); (c) studio profiles 400K + member profiles 50K + search 45K + options 25K (worst 160K) + sweeps 15K ≈ 535K–670K reads ($0.32–0.40), writes ~30K ($0.05).
- **Conclusion:** (b) **≈ $0.06/month**; (c) **≈ $0.55–0.60/month** (incl. Functions under the one rule and the capacity recompute of Decision 26), under the $5 threshold. Kept low by: members row limited to 10 with `get`, search only on ≥ 2 characters through one callable, S26.04 computed server-side once per open, sweeps folded into the existing `bookingClock`.

## Tasks

### Task 1: Contract re-check after #130, mock frames, spec rows

**Files:**
- Modify: `docs/design/ui-mock.html` (S26 section, S03 group, S05 group, S06 group, S09 group), `docs/superpowers/specs/2026-10-06-studio-members-design.md` (§3.1 relation id and public membership via `photographers.studioId`, Decisions 1–2; §5.2 deadline rule, Decision 8; §5.7 assignee contact, Decision 17; §6 studio reason labels), `docs/superpowers/specs/2026-10-01-remaining-screens.md` (§2 S26 rows "⬜ có mock, đang làm (#136)"), `app_flutter/lib/core/screen_codes.dart` (check only)
- Create: `docs/superpowers/handover/ledger-s26-studio-members.md` (first section "Contract after #130": the real names of the review input, `VerdictPad` API, `tomatoPct` fields, the `shot` action and the late-delivery hook)

**Interfaces:** Produces mock frames `S03.01-member`, `S06.01-studio`, `S06.01-member`, `S09.02-studio`, `S05.02-studio-change`, `S26.03-none`; edits `#S26.03` (adds a "Từ chối" text button beside "Nhận"), `#S26.01` caption (empty state copy).

- [ ] **Step 1: Contract check** of every bullet above against `develop` **with #130 merged**; write the #130 names into the ledger. If #130 is not merged, stop.
- [ ] **Step 2: Add the frames** (`.step` + `.phone` + `.cap`, `<span class="ms">`, existing classes; copy exactly from Contract §L10n):
  - `S03.01-member`: Minh Trí's profile header (as `#S03.01`) with, under the name, a `ptag` with `work` icon "Thành viên của Studio Mây" (tappable to the studio). Caption: shown on members' profiles only; the studio stays the one booked.
  - `S06.01-studio`: studio owner's Công việc: an accepted studio booking card with `badge` "Đã nhận", meta "Hạn giao thợ: 15:30 T6 11/10" and `btn out sm` "Giao thợ"; a second card "Thợ: Minh Trí" with a row "Khách xin đổi thợ · trả lời trước 14:30" + `btn out xs` "Từ chối đổi" (and the assign button reopening S26.04).
  - `S06.01-member`: member's Công việc: a booking card with `ptag` "Giao bởi Studio Mây" and `btn txt sm` (red) "Trả việc"; after returning, meta "Đã trả việc · chờ studio giao lại".
  - `S09.02-studio`: `#S09.02` with a Tài khoản row `group` "Thành viên studio" / "6/30 thợ"; caption: a photographer sees "Studio của tôi" / "Studio Mây" (or "Chưa ở studio nào").
  - `S05.02-studio-change`: like `#S05.02-studio-late` but `warnc` "Studio không đổi thợ chụp" / "Lý do: Thợ nữ đã kín lịch ngày này. Bạn giữ thợ hiện tại hoặc huỷ và được hoàn 100%."; the assigned member card stays above; red text "Huỷ và hoàn 100%"; caption lists the expired and late-reassign variants and "Đã xin đổi · chờ studio".
  - `S26.03-none`: "Studio của tôi" with the empty state "Bạn chưa ở studio nào" + body, a pending own request row "Đã xin gia nhập Studio Mây · chờ duyệt" + "Huỷ", the invites section, the cooldown note.
- [ ] **Step 3: Check** unique ids, balanced `div`s in the edited groups, every new string present in Contract §L10n.
- [ ] **Step 4: Commit** `docs(mock): S26 member label, studio work cards, settings rows and change-declined state [#136]`.

### Task 2: Domain — membership, anti-spam, provider type guard

**Files:**
- Create: `packages/domain/src/studio_membership.ts`, `studio_ports.ts`, `studio_use_cases.ts`, `memory_studio_store.ts`; tests `packages/domain/test/studio_membership.test.ts`, `studio_use_cases.test.ts`, `test/support/studio_world.ts`
- Modify: `src/errors.ts`, `src/set_provider_type.ts`, `src/provider_ports.ts`, `src/memory_provider_store.ts`, `src/index.ts`; `test/set_provider_type.test.ts` (no notification module: #138's)

**Interfaces:** Consumes `ProviderType`, `DomainError`, `notify` types, `foldVietnamese`. Produces Contract §Domain `studio_membership.ts`, `studio_ports.ts` (minus `StudioRoster` use), `studio_use_cases.ts`, the five error codes (skip `rate_limited`, which #135 added), `membershipNotices` (decider; copy and hooks are #138's). `studio_world.ts`: studio `s1` (onboarded, not business-verified, name "Studio Mây"), `s2`, photographers `m1`–`m5` (individual, onboarded), artist `a1`, unfinished `u1`, `ControllableClock` at `2026-10-10T10:00Z` (17:00 VN), open-booking counts settable per (studio, member).

Sample (accept an invite; the member doc is the lock):

```ts
return deps.studios.runTransaction(async (tx) => {
  const rel = await tx.getRelation(input.relationId);
  if (rel === null || rel.memberId !== memberId) throw new DomainError('not_found');
  if (rel.status !== 'invited') throw new DomainError('conflict');
  const member = await tx.getProfile(memberId);
  const studio = await tx.getProfile(rel.studioId);
  // ---- all reads above ----
  if (Date.parse(rel.expiresAt) <= now.getTime()) {
    tx.putRelation({ ...rel, status: 'expired', version: rel.version + 1 });   // record, then refuse outside
    return { outcome: 'expired' as const };
  }
  if (!input.accept) { tx.putRelation({ ...rel, status: 'declined', respondedAt: nowIso, version: rel.version + 1 }); return { outcome: 'ok' as const, … }; }
  if (member!.studioId !== null) throw new DomainError('membership_conflict');
  if (inCooldown(member!, now)) throw new DomainError('cooldown');
  if (studio!.memberCount >= maxMembers(studio!)) throw new DomainError('studio_full');
  tx.putRelation({ ...rel, status: 'active', respondedAt: nowIso, joinedAt: nowIso, version: rel.version + 1 });
  tx.setMemberStudio(memberId, { studioId: rel.studioId, studioJoinedAt: nowIso });
  tx.addMemberCount(rel.studioId, 1);
  return { outcome: 'ok' as const, … };
});
```

- [ ] **Step 1: Contract check** (provider ports, error list after #135).
- [ ] **Step 2: Failing tests** — rules: "maxMembers is 3, 30 when businessVerified"; "artist and individual can join, studio and unfinished cannot"; "cooldown ends exactly 7 days after endedAt"; "quotaLeft resets at 00:00 VN (17:00 UTC)"; "isOpenBookingStatus is false only for declined, expired, cancelled, completed, reviewed"; "foldNameKey folds marks and lower-cases (Hồng Nhung → hong nhung)". Use cases: "invite creates an invited relation expiring in 7 days and counts a studio action"; "invite of a member active elsewhere is membership_conflict"; "invite during cooldown is cooldown"; "a sixth open invite is studio_full"; "members + invites over 3 is studio_full, 30 when verified"; "a second open relation of the same pair is conflict"; "the sixth studio action of the VN day is rate_limited; the next day works"; "a studio cannot invite itself or another studio (invalid_argument)"; "cancelInvite only by its studio and only while invited"; "requestToJoin counts a member action; the fourth is rate_limited"; "respondInvite accept makes the member active, sets studioId and memberCount"; "accepting after expiresAt records expired and answers deadline_passed"; "decline is free of quota"; "parallel accepts of two invites: one active, the other membership_conflict"; "respondJoinRequest approve checks the cap and counts; decline is free"; "leave sets left, cooldown until +7 days, memberCount −1"; "leave with an open studio booking is member_busy"; "removeMember is the studio's, sets removed and notifies"; "runMembershipSweeps expires due relations once and lists invites expiring within 24 h without a notice yet"; "membershipNotices sends the right type to the right party". Provider type: "a studio with members cannot become individual (membership_conflict)"; "a member cannot become a studio"; "an open invite also blocks". Render: the six membership types render the Contract copy.
- [ ] **Step 3: Run** `(cd packages/domain && npm test)` → fail.
- [ ] **Step 4: Implement** (memory store with the read-after-write guard; quota inside the same transaction; refusals that must record state return an outcome and throw after commit, as in the sample).
- [ ] **Step 5: Run** `(cd packages/domain && npm test && npm run lint)` → pass.
- [ ] **Step 6: Commit** `feat(domain): studio membership with limits, cooldown and daily quota [#136]`.

### Task 3: Domain — studio bookings: assignment, change request, return, 100% refund, sweeps, chat

**Files:**
- Create: `packages/domain/src/studio_assignment.ts`, `studio_notifications.ts`, `studio_capacity.ts` (Decision 26); tests `test/studio_assignment.test.ts`, `test/studio_booking_sweeps.test.ts`, `test/studio_notifications.test.ts`, `test/studio_capacity.test.ts`; extend `test/support/booking_world.ts` (roster map, member days, studio provider type)
- Modify: `src/booking.ts`, `src/booking_ports.ts` (`orderProfile`, `StudioBookingTx`), `src/memory_booking_store.ts`, `src/create_booking.ts`, `src/booking_machine.ts`, `src/transition_booking.ts`, `src/commit_transition.ts`, `src/booking_notifications.ts`, `src/chat.ts`, `src/booking_chat_sync.ts`, `src/index.ts`; #130's late-delivery handler (one line, Decision 15); tests `create_booking.test.ts`, `booking_machine.test.ts`, `transition_booking.test.ts`, `booking_chat_sync.test.ts`, `booking_notifications.test.ts`

**Interfaces:** Consumes Task 2 (`isOpenBookingStatus`), `ProviderOrderGate`, `commitTransition`, `parseVnDateTime`. Produces Contract §Domain `studio_assignment.ts`, `studio_notifications.ts` (`studioBookingNotices` decider), the booking/machine/chat changes. Consumes #152's `buildBookingDraft`/`BookingDraftInput` and #144's `orderBlocker(deps: OrderGateDeps, p: {customerId, providerId}): Promise<'not_accepting_orders' | 'blocked' | null>` (#129 built neither, `2026-10-08-s04-reconciliation.md`).

Sample (assignment; every read before the first write):

```ts
const booking = await deps.store.getBooking(input.bookingId);
if (!booking || booking.isStudio !== true) throw new DomainError('not_found');
if (booking.photographerId !== callerId) throw new DomainError('permission_denied');
const kind = await deps.roster.relationOf(booking.photographerId, input.assigneeId);
if (kind === null) throw new DomainError('permission_denied');
if (!(await deps.providers.acceptsOrders(booking.photographerId))) throw new DomainError('not_accepting_orders');
const blocker = await orderBlocker(deps, { customerId: booking.customerId, providerId: input.assigneeId }); // #144 (provider gate + BlockGate)
if (blocker !== null) throw new DomainError(blocker);   // 'not_accepting_orders' | 'blocked'
return deps.store.runTransaction(async (tx) => {
  const b = await tx.getBooking(booking.id);
  if (!b || b.version !== booking.version) throw new DomainError('conflict');
  const startsAt = parseVnDateTime(b.day, b.start);
  if (!['accepted', 'upcoming'].includes(b.status) || now >= startsAt) throw new DomainError('not_eligible');
  if (b.assigneeId === input.assigneeId) throw new DomainError('conflict');
  const day = await tx.getAvailabilityDay(input.assigneeId, b.day);
  if (day && day.bookingId !== b.id) throw new DomainError('day_taken');
  const oldDay = b.assigneeId ? await tx.getAvailabilityDay(b.assigneeId, b.day) : null;
  // ---- writes ----
  const late = b.assigneeId !== null && now >= new Date(b.assignDeadline!);
  tx.setAvailabilityDay(input.assigneeId, b.day, { state: 'booked', bookingId: b.id });
  if (b.assigneeId && oldDay?.bookingId === b.id) tx.deleteAvailabilityDay(b.assigneeId, b.day);
  if (late) tx.incrementStudioCounter(b.photographerId, 'lateReassignCount');
  const next = { ...b, assigneeId: input.assigneeId, assigneeKind: kind, assignStatus: 'assigned', assignedAt: nowIso,
    assignments: [...b.assignments!, { assigneeId: input.assigneeId, assigneeKind: kind, at: nowIso, by: callerId, reason: null, late }],
    changeRequest: b.changeRequest?.status === 'pending' ? { ...b.changeRequest, status: 'reassigned', answeredAt: nowIso } : b.changeRequest,
    studioFault: late ? { kind: 'late_reassign', at: nowIso } : b.studioFault?.kind === 'assign_overdue' ? null : b.studioFault,
    assignmentReturned: null,
    status: b.status === 'accepted' && startsAt.getTime() - now.getTime() <= 24 * HOUR_MS ? 'upcoming' : b.status,
    version: b.version + 1, updatedAt: nowIso } as Booking;
  await tx.setBooking(next);
  return next;
});
```

- [ ] **Step 1: Contract check** (booking ports and #130's states/actions; ledger).
- [ ] **Step 2: Failing tests** — creation: "a booking with a studio is isStudio, unassigned, deadline 24 h before start"; "a studio booking starting in 10 h gets a deadline 2 h from now"; "an individual booking carries no studio fields"; "orderProfile closed is not_accepting_orders" (existing test kept). Assignment: "the studio assigns a free verified member: booking assigned, member day booked, assignment logged"; "a member busy that day is day_taken and nothing is written"; "an unverified member is not_accepting_orders"; "a member blocked by the customer (either way) is blocked"; "a quote booking of a studio (built through buildBookingDraft) carries the studio fields"; capacity (Decision 26, `studio_capacity.test.ts`): "a studio with 3 free members takes 3 bookings that day"; "the 4th is refused (day_taken)"; "a member's personal booking reduces the studio's capacity"; "a member's personal booking is refused when the studio needs that member that day"; "assigning blocks the member's day and keeps the studio's capacity"; "an unverified member adds no capacity"; "a studio off day takes nothing"; "cancelling an unassigned studio booking frees a place"; "a non-member is permission_denied"; "only the studio owner assigns"; "a requested or cancelled booking is not_eligible"; "after the start is not_eligible"; "the same assignee again is conflict"; "reassign frees the old member's day and books the new one"; "reassign after the deadline sets late_reassign and lateReassignCount"; "assigning an overdue booking clears assign_overdue but keeps assignOverdue history"; "assigning an accepted booking inside 24 h makes it upcoming"; "assignmentOptions marks free, busy with the occupying times, off day, unverified and current". Machine: "upcoming refuses a studio booking without assignee"; "accept inside 24 h keeps an unassigned studio booking accepted"; "the assignee may complete, not accept or cancel"; "cancel_studio_fault refunds 100% when overdue (before the sweep)"; "cancel_studio_fault without a fault is not_eligible"; "a second cancel_studio_fault is conflict"; "cancel frees the assignee's day". Change: "one change request per booking; a second is conflict"; "respondBy is 6 h, or the start when sooner"; "declineAssigneeChange needs a reason and sets change_declined + changeDeclinedCount"; "reassigning answers the request reassigned". Return: "only the assignee returns; assigneeId stays; the studio is told". Sweeps: "overdue marks once, counts lateAssignCount once, notifies customer and studio"; "reminders at 48 h and 26 h fire once each"; "pending change past respondBy expires with change_expired"; "a sweep run twice changes nothing more". Chat: "the assignee is a chat member and speaks as the studio side"; "reassign replaces the chat member"; "a new booking with the same studio resets the assignee". Notices: "studioBookingNotices: assigned → customer and assignee; reassigned → customer, old and new; change requested → studio; declined/expired → customer; returned → studio; cancel by studio_fault notifies only the studio". Render: the seven booking types render the Contract copy.
- [ ] **Step 3: Run** `(cd packages/domain && npm test)` → fail.
- [ ] **Step 4: Implement.**
- [ ] **Step 5: Run** `(cd packages/domain && npm test && npm run lint)` → pass.
- [ ] **Step 6: Commit** `feat(domain): studio assignment, change request, studio-fault refund and sweeps [#136]`.

### Task 4: Domain — two-sided reviews on the tomato/brick model

**Files:**
- Modify: `packages/domain/src/review.ts`, `src/submit_review.ts`, `src/review_ports.ts`, `src/memory_review_store.ts`, `src/review_stats.ts` (review id, not booking id), `src/index.ts`; tests `test/review.test.ts`, `test/submit_review.test.ts`, `test/review_stats.test.ts`

**Interfaces:** Consumes #130's `validateReviewInput`, verdict fields, `intensityOf`, `countReview(store, reviewId, now)`, `reviewDocId(bookingId, subjectType)`, `ReviewSubjectType`, `ReviewTx.getReview(reviewId)` (plan `2026-10-07-s05-tomato-brick-reviews.md` Decision 2: the subject model and the `_studio` doc id already exist; this task adds the studio block, the studio reason codes and the second write). Produces `STUDIO_BRICK_REASONS`, `validateReviewInput(raw, callerId, prefixes, { studio })`, `submitReview` writing one or two documents (Decision 21), `ReviewTx.getUserName(uid)` for the snapshots, `countReview(store, reviewId, now)`.

- [ ] **Step 1: Contract check** of #130's review module (names in the ledger from Task 1).
- [ ] **Step 2: Failing tests:** "an individual booking accepts no studio block (invalid_argument)"; "a studio booking needs the studio block (invalid_argument without)"; "studio brick reasons are the five studio codes; a photographer code is invalid there"; "a studio tomato block with reasons is invalid"; "submit writes reviews/{id} for the last assignee and reviews/{id}_studio for the studio in one transaction"; "the member review carries viaStudioId and name; the studio review carries assigneeId and name"; "intensity is computed per block"; "a studio booking without an assignee is not_eligible"; "either document already existing is conflict"; "countReview counts reviews/{id}_studio into the studio's stats and reviews/{id} into the member's, once each"; "the real-shoot post keeps photographerId = studio and adds assigneeId".
- [ ] **Step 3: Run** → fail. **Step 4: Implement.** **Step 5: Run** `(cd packages/domain && npm test && npm run lint)` → pass.
- [ ] **Step 6: Commit** `feat(domain): two-sided reviews for studio bookings [#136]`.

### Task 5: Functions, rules, indexes, trigger, clock, seed

**Files:**
- Create: `app_flutter/firebase/functions/src/infra/studio_firestore.ts` (`FirestoreStudioStore`, `FirestoreStudioRoster`, `FirestoreMemberDayReader`), `src/infra/live_studio.ts`, `src/callables/studio.ts`, `src/triggers/user_write.ts`; tests `test/unit/studio_callables.test.ts`, `test/unit/studio_firestore.test.ts`, `test/unit/user_write.test.ts`, `test/integration/studio.test.ts`
- Modify: `src/index.ts` (14 callables, `onUserWrite`), `src/callables/errors.ts`, `src/callables/booking.ts` (`cancel_studio_fault`), `src/callables/review.ts` (`studio` block), `src/infra/booking_firestore.ts` (studio fields, `incrementStudioCounter`, queries), `src/infra/booking_readers.ts` (`orderProfile`), `src/infra/chat_firestore.ts` (`assigneeId`, members), `src/triggers/booking_write.ts` (`studioBookingNotices`), `src/triggers/review_write.ts` (review id), `src/triggers/photographer_write.ts` (`nameKey` heal), `src/scheduled/booking_clock.ts` (studio steps), `src/infra/studio_capacity_firestore.ts` (new: `recomputeStudioDay(studioId, day)` writing `availability/{studioId}/days/{day}` `full` or deleting it, Decision 26), the availability-day trigger of #132 (`triggers/availability_write.ts`: also `recomputeStudioDay` for a member with a `studioId`), `seed/fixtures.ts`, `seed/README.md`; `app_flutter/firebase/firestore.rules`, `firestore.indexes.json`, `rules-test/rules.test.mjs`; every test that builds a `ProviderOrderGate` fake

**Interfaces:** Consumes Tasks 2–4. Produces Contract §Callables, `onUserWrite`, the rules and indexes. `handleBookingClock` gains the steps `studioAssignSweeps`, `studioChangeSweeps`, `studioMembershipSweeps` at the end of its step list, each in its own try/log, dependencies in the optional `BookingClockExtras.studio?: { bookings: StudioBookingDeps; members: StudioDeps; notify: NotifyDeps }` (clock rule, restated in `2026-10-08-s04-reconciliation.md`). `searchPhotographersToInvite` runs the range query with the Admin SDK and assembles rows (Decision 19). Membership callables call `membershipNotices` after commit (logged, never thrown).

- [ ] **Step 1: Contract check** (Functions bullets, ledger).
- [ ] **Step 2: Failing tests.** Unit: "unauthenticated refused"; "each membership callable passes the caller uid as the right party"; "new codes map to failed-precondition / resource-exhausted"; "studio booking fields round-trip through the Firestore mapping"; "chat members include the assignee"; "orderProfile reads providerType with the gate in one read"; "searchPhotographersToInvite needs 2 characters, returns ≤ 20 rows with states"; "assignmentOptions returns busy times from the occupying booking"; "onUserWrite writes nameKey only when displayName changes and a photographer doc exists"; "onPhotographerWrite heals a missing nameKey once"; "onReviewWrite counts reviews/{id}_studio by its own id"; "bookingClock runs the studio steps and survives their failure"; "recomputeStudioDay writes full when load reaches capacity and deletes it when a place frees"; "a member's personal booking day triggers the studio recompute"; integration (write, do not run): "Cúc with three free members takes three bookings the same day; the fourth createBooking is day_taken". Integration (write, do not run): "invite → accept → assign → customer reads the assignee on the booking"; "two parallel accepts: one active"; "reassign: the old member cannot read the booking"; "overdue sweep then cancel_studio_fault refunds 100%". Rules (write, do not run): "the studio and the member read their relation; a third user cannot"; "nobody writes studio_members or studio_quota"; "the owner reads their quota"; "the assignee reads the booking and its events"; "a former assignee cannot read the booking"; "the assignee reads the customer contact only while unlocked"; "a client cannot set studioId, memberCount, nameKey or the counters on photographers".
- [ ] **Step 3: Run** `(cd app_flutter/firebase/functions && npm test)` → fail.
- [ ] **Step 4: Implement.** Seed: Cúc studio `verified: true`, `memberCount: 1`; An active member of Cúc since 30 days (`studioId`, relation `active`); Bình invited by Cúc (expires in 5 days); Dũng (artist) with an open request to Cúc; `nameKey` on every seeded photographer; booking `seed-booking-studio-assigned` (Lan ↔ Cúc, accepted, assigned to An, 3 days ahead) and `seed-booking-studio-unassigned` (Lan ↔ Cúc, accepted, starts in 20 h, unassigned → the first `bookingClock` marks it overdue). Seed README table "Studio (S26)".
- [ ] **Step 5: Run** `(cd app_flutter/firebase/functions && npm test && npm run build)` and `(cd packages/domain && npm test)` → pass. Ledger the unrun suites.
- [ ] **Step 6: Commit** `feat(functions): studio membership and assignment callables, rules and clock steps [#136]`.

### Task 6: App data — studio repository, booking fields, members, review submit, chat mapping

**Files:**
- Create: `app_flutter/lib/data/studio/studio_relation.dart`, `studio_repository.dart`, `firestore_studio_repository.dart`, `studio_providers.dart`, `lib/data/booking/studio_booking.dart`; tests `test/data/studio/studio_mapping_test.dart`, `studio_repository_test.dart`, `test/data/booking/studio_booking_mapping_test.dart`, `test/data/content/members_of_test.dart`, `test/data/review/studio_review_submit_test.dart`, `test/data/chat/assignee_chat_mapping_test.dart`; `test/support/studio_world.dart`
- Modify: `lib/data/booking/booking.dart` (+ regenerated `booking.freezed.dart`, `booking.g.dart`), `booking_repository.dart`, `firestore_booking_repository.dart`, `booking_providers.dart` (nothing new: #134's `assignedBookingsProvider` is reused), `test/support/fake_booking_repository.dart`, `lib/data/content/photographer_summary.dart`, `content_repositories.dart`, `firestore_photographer_repository.dart`, `fake_content_repositories.dart`, `lib/data/review/review.dart`, `review_repository.dart`, `firestore_review_repository.dart`, `test/support/fake_review_repository.dart`, `lib/data/chat/` (counterpart for the assignee), `lib/data/photographer/photographer_intro.dart` (`providerType`, `studioId` if #135 has not added them)

**Interfaces:** Produces Contract §Dart data parts. `bookingFromFirestore` parses `studio` only when `isStudio == true`. `FirestoreStudioRepository` maps callable errors to `StudioError(details.code)`. The assignee's chat counterpart is the customer.

- [ ] **Step 1: Contract check** (Dart bullets; how the chat model picks the counterpart).
- [ ] **Step 2: Failing tests:** "relation statuses and snapshots map"; "quota left resets on another VN day"; "studio booking info maps assignee, deadline, change request, fault, returned"; "an individual booking has studio == null"; "cancelStudioFault sends cancel_studio_fault"; "assign/requestChange/declineChange/returnAssignment send the documented payloads"; "membersOf queries studioId ordered by join date, limit 10, and builds summaries"; "PhotographerSummary carries studioId and memberCount"; "submit with a studio draft sends both blocks"; "a studio review maps subjectType, viaStudioName, assigneeName"; "the assignee sees the customer as the chat counterpart"; "StudioError carries the server code".
- [ ] **Step 3: Run** `flutter test --no-pub --timeout 60s test/data/studio` (then `test/data/booking`, `test/data/content`, `test/data/review`, `test/data/chat`) → fail.
- [ ] **Step 4: Implement**; `dart run build_runner build --delete-conflicting-outputs`.
- [ ] **Step 5: Run** `flutter analyze`; the five folders one at a time → pass.
- [ ] **Step 6: Commit** `feat(data): studio relations, studio booking fields and two-sided review submit [#136]`.

### Task 7: S26.01 Thành viên studio, S26.02 Mời thợ, S26.03 Studio của tôi, S09.02 rows

**Files:**
- Create: `app_flutter/lib/features/studio/studio_members_screen.dart`, `invite_member_sheet.dart`, `my_studio_screen.dart`, `studio_errors.dart`, `lib/core/widgets/member_row.dart` (export in `core.dart`); tests `test/features/studio/studio_members_screen_test.dart`, `invite_member_sheet_test.dart`, `my_studio_screen_test.dart`, `test/core/widgets/member_row_test.dart`, `test/features/settings/settings_studio_rows_test.dart`
- Modify: `lib/app/router.dart` (`/studio/members`, `/me/studio`), `lib/features/settings/settings_screen.dart` (rows of group Tài khoản per S09's order, #148 Decision 12: flip `studioRoutesReadyProvider` to `true` in `lib/features/settings/settings_links.dart` and add the status subtitles (`settingsStudioMembersQuota`, `settingsMyStudioNone`) to its existing rows `settings-my-studio` / `settings-studio-members`; no new rows), `lib/l10n/app_vi.arb`

**Interfaces:** Consumes `myStudioRelationsProvider`, `myMemberRelationsProvider`, `studioQuotaProvider`, `studioRepositoryProvider`, `photographerBookingsStreamProvider` (studio's open bookings grouped by `assigneeId` for "{m} việc đang giao" and the busy count), #134's `assignedBookingsProvider` (member's jobs), `myIntroProvider`. Produces `StudioMembersScreen`, `showInviteMemberSheet(context)`, `MyStudioScreen`, `MemberRow({avatarUrl, name, meta, trailing, enabled = true, onTap})`, `studioErrorText(BuildContext, String code)`.

**Backend wiring:** listeners on `studio_members` (rules: party read; indexes `(studioId, status, createdAt)`, `(memberId, status, createdAt)`) and `studio_quota/{uid}`; `photographers where studioId == me` for active members' summaries (`membersOf`); callables `inviteMember`, `cancelInvite`, `respondJoinRequest`, `removeMember`, `searchPhotographersToInvite`, `respondInvite`, `leaveStudio`, `cancelJoinRequest`.
**Mock parity:** `#S26.01` (bar "Thành viên" + info button opening the rules sheet, quota line, members card with avatar, name, 🍅 % (`formatTomatoPct` from #130), "{m} việc đang giao"/"chưa có việc", "…" menu; "Đang chờ" header with count; pending invite row with expiry and "Huỷ"; request row with "Từ chối"/"Duyệt" outline buttons; primary "Mời thợ"; cap banner with "Xác minh doanh nghiệp" link only when the `/verify/business` route exists); `#S26.02` (sheet title + close, search field, rows with verified tick, %, area, outline "Mời"; disabled rows with reason text; footnote; all "Mời" disabled with the reason line when 5 invites or no quota; no gradient button); `#S26.03` and `#S26.03-none` (studio card with seal/tick, since-line, "Xem studio"; "Việc studio giao" list with "Đã giao" badges; red text "Rời studio"; invites with "Nhận"/"Từ chối", dimmed with reason while in a studio; cooldown note; no gradient button); `#S09.02-studio` rows.

- [ ] **Step 1: Contract check** (settings tile pattern, `formatTomatoPct` name).
- [ ] **Step 2: Failing tests:** S26.01 — "shows the quota line 6/30 thợ · còn 4 thao tác hôm nay"; "lists active members with % and assigned counts from the studio's bookings"; "pending invite shows days left and Huỷ cancels"; "a request shows Từ chối and Duyệt; Duyệt approves"; "Mời thợ opens S26.02"; "remove opens a red confirmation sheet and removes"; "remove of a member with 2 open jobs shows Còn 2 buổi chụp được giao and no remove button"; "at the cap without business verification shows the banner (link hidden when the route is absent)"; "no quota disables actions and shows studioQuotaOut"; "empty studio shows the empty state"; "server errors show studioErrorText". S26.02 — "typing 2+ characters searches; 1 character does not"; "rows show Đang ở {studio} and Mời được từ {date} dimmed"; "Mời invites and the row becomes Đã mời with a SnackBar"; "five open invites disable every Mời with the reason line"; "no results text". S26.03 — "a member sees the studio card, jobs and Rời studio"; "Rời studio confirms in a red sheet and leaves"; "leaving with open jobs shows the busy body and no leave button"; "invites while in a studio are dimmed with Bạn đang ở {studio}"; "Nhận accepts, Từ chối declines"; "not in a studio shows the empty state and a pending own request with Huỷ". S09.02 — "a studio sees Thành viên studio with {n}/{max} thợ"; "a photographer sees Studio của tôi with the studio name or Chưa ở studio nào"; "a customer sees neither". Each screen: "fits 320dp at 1.3x text". `MemberRow`: "renders avatar, name, meta and trailing; disabled is dimmed and not tappable; semantics".
- [ ] **Step 3: Run** `flutter test --no-pub --timeout 60s test/features/studio` → fail.
- [ ] **Step 4: Implement**; arb keys; `flutter gen-l10n`.
- [ ] **Step 5: Run** `flutter analyze`; `test/features/studio`, `test/features/settings`, `test/core/widgets` one at a time → pass.
- [ ] **Step 6: Commit** `feat(studio): S26.01 members, S26.02 invite, S26.03 my studio and settings rows [#136]`.

### Task 8: S03.01 studio variant and member label, S06.01 studio and member cards, S26.04 Giao thợ

**Files:**
- Create: `app_flutter/lib/features/studio/assign_sheet.dart`, `decline_change_sheet.dart`, `return_job_sheet.dart`, `lib/core/widgets/member_strip.dart` (export); tests `test/features/studio/assign_sheet_test.dart`, `test/features/photographer_profile/studio_profile_test.dart`, `test/features/work/studio_work_cards_test.dart`, `test/core/widgets/member_strip_test.dart`
- Modify: `lib/features/photographer_profile/widgets/profile_header.dart` (studio stat tiles, members row, member label), `widgets/profile_bottom_bar.dart` or `photographer_profile_screen.dart` ("Xin gia nhập" placement per mock: outline button in the members section header), `lib/features/work/work_screen.dart` (`_RequestCard` studio and member variants; member's list merges `assignedBookingsStreamProvider` — if #134 has merged, its second listener on `bookings where assigneeId == uid` and the "Giao bởi {Studio}" pill already exist: reuse them, add only "Trả việc" and the studio-owner actions), `lib/features/booking/booking_detail_screen.dart` (owner: "Giao thợ" in the actions; assignee: no S06.07 entry), `lib/l10n/app_vi.arb`

**Studio capacity in the app (Decision 26, owner 2026-10-07):** also modify `lib/core/widgets/availability_calendar.dart` (`DayState.full`, drawn like `booked` with the label `calendarDayFull` "Hết chỗ"), `lib/data/photographer/availability_repository.dart` (maps the server state `full`), `lib/features/booking/steps/datetime_step.dart` (S04.02: a `full` day of a studio is not selectable; nothing else changes for individuals), tests `test/core/widgets/availability_calendar_test.dart` ("a full day shows Hết chỗ and is not tappable") and `test/features/booking/datetime_step_test.dart` ("a studio's full day cannot be picked; a day with a free member can"). The S26.04 list keeps showing each member's own state (Rảnh / Bận / Chưa xác minh) from `assignmentOptions`.

**Interfaces:** Consumes `studioMembersProvider(studioId)`, `myMemberRelationsProvider`, `studioRepositoryProvider.assignmentOptions/requestToJoin`, `bookingRepositoryProvider.assign/declineChange/returnAssignment`, `userRepositoryProvider` (studio name for the label). Produces `showAssignSheet(context, bookingId)`, `showDeclineChangeSheet`, `showReturnJobSheet`, `MemberStrip({members, total, onTap})`.

**Backend wiring:** `photographers where studioId == X order by studioJoinedAt limit 10` (index) + `users` docs; `users/{studioId}` for the label; callables `requestToJoin`, `assignmentOptions`, `assignBooking`, `declineAssigneeChange`, `returnAssignment`; listener `bookings where assigneeId == me` (rules: assignee read; index `(assigneeId, createdAt desc)`).
**Mock parity:** `#S03.01-studio` (seal, "Studio" tag, stats: % cà chua · buổi chụp · thành viên · năm hoạt động; "Thành viên" section with outline "Xin gia nhập" only for an independent photographer not in a studio; strip of members with %, "+n"; tabs and bottom bar unchanged); `#S03.01-member` (label "Thành viên của {Studio}" under the name, taps to the studio); `#S06.01-studio` (assign button, deadline meta, "Thợ: {name}", change-request row with "Từ chối đổi"); `#S06.01-member` ("Giao bởi {Studio}" tag, red text "Trả việc", returned meta); `#S26.04` (sheet over Công việc: summary card with deadline and time left, radio list of members with Rảnh/Bận {giờ}/Bận cả ngày/Chưa xác minh (disabled dimmed), info note naming the chosen member, primary "Giao cho {name}"; late warning line inside 24 h).

- [ ] **Step 1: Contract check** (header slots, `_RequestCard` structure, booking detail action row).
- [ ] **Step 2: Failing tests:** profile — "a studio shows the four stat tiles with members and years"; "the members strip shows 4 members with % and +2"; "an independent photographer not in a studio sees Xin gia nhập and sending shows Đã xin gia nhập"; "a customer, a member of any studio and the studio itself do not see it"; "cooldown answer shows profileJoinCooldown"; "a member's profile shows Thành viên của Studio Mây and taps to the studio"; "an individual not in a studio shows no label". Work — "an accepted unassigned studio booking shows Giao thợ and the deadline"; "an overdue one shows Quá hạn giao thợ"; "an assigned one shows Thợ: Minh Trí"; "a pending change shows the request row; Từ chối đổi needs a reason in a red sheet"; "a member sees studio jobs tagged Giao bởi Studio Mây beside personal jobs"; "Trả việc confirms in a red sheet and shows Đã trả việc · chờ studio giao lại"; "the assignee's booking detail has no delivery entry". Assign sheet — "lists members with Rảnh, Bận 15:00–18:00, Bận cả ngày, Chưa xác minh (disabled)"; "the primary label names the selected member"; "assigning calls assignBooking and closes"; "inside 24 h shows assignLateWarning"; "day_taken and not_accepting_orders show studioErrorText"; "no members shows assignNoMembers"; "fits 320dp at 1.3x text". `MemberStrip`: "shows up to 4 and +n; semantics list".
- [ ] **Step 3: Run** `flutter test --no-pub --timeout 60s test/features/studio` (then `test/features/photographer_profile`, `test/features/work`, `test/core/widgets`) → fail.
- [ ] **Step 4: Implement**; arb keys; `flutter gen-l10n`.
- [ ] **Step 5: Run** `flutter analyze`; the four folders one at a time → pass.
- [ ] **Step 6: Commit** `feat(studio): studio profile members, member label, S26.04 assignment and work cards [#136]`.

### Task 9: Customer side — S05.02 "Thợ chụp cho bạn", S26.05, studio-fault cancel, S05.05 two blocks

**Files:**
- Create: `app_flutter/lib/core/widgets/assignee_card.dart` (export), `lib/features/studio/change_request_sheet.dart`; tests `test/core/widgets/assignee_card_test.dart`, `test/features/booking/studio_booking_detail_test.dart`, `test/features/studio/change_request_sheet_test.dart`, `test/features/review/studio_review_test.dart`
- Modify: `lib/features/booking/booking_detail_screen.dart` (block, timeline rows, "Nhắn studio"), `lib/features/booking/cancel_sheet.dart` (`studioFault` mode), `lib/features/booking/booking_view_rules.dart` (studio state helpers), `lib/features/review/review_screen.dart`, `review_controller.dart` (two blocks), `lib/features/photographer_profile/widgets/profile_sections.dart` (review tags "Chụp bởi {name}" / "Qua {studio}"), `lib/l10n/app_vi.arb`

**Interfaces:** Consumes `Booking.studio`, `bookingRepositoryProvider.requestChange/transitionBooking(cancelStudioFault)`, `photographerProfileProvider(assigneeId)`, #130's `VerdictPad` (compact variant if #130 has one; else a `compact` flag added here) and `ReviewRepository.submit(studio:)`. Produces `AssigneeCard({summary, studioName, assignedOn, changeLabel, onViewProfile, onChange})`, `showChangeRequestSheet(context, booking)`, `studioBlockStateOf(Booking, DateTime now) → StudioBlockState {waiting, assigned, changePending, overdue, changeDeclined, changeExpired, lateReassign}`.

**Backend wiring:** `bookingProvider` listener (rules: customer read); `photographers/{assigneeId}` + `users/{assigneeId}` via `photographerProfileProvider`; callables `requestAssigneeChange`, `transitionBooking({action: 'cancel_studio_fault'})`, `submitReview({…, studio})`; refunds through the fake gateway.
**Mock parity:** `#S05.02-studio` (section "Thợ chụp cho bạn" + "Giao {date}", card: avatar, name, tick, 🍅 %, "{n} buổi · thợ của {studio}", "Xem hồ sơ", outline "Xin đổi thợ (1 lần)"; timeline rows; footer `ContactDial` + primary "Nhắn studio"); waiting state line "Studio sẽ báo thợ chụp trước {deadline}"; `#S05.02-studio-late` (section label "Quá hạn" in red, `warnc` title/body, red text "Huỷ và hoàn 100%", reminded line, timeline "Chờ studio giao thợ chụp"); `#S05.02-studio-change` (declined, expired, late-reassign texts); "Đã xin đổi · chờ studio" disabled outline; `#S26.05` (sheet: current member card, reason field optional, info note two lines, "Bạn chỉ xin đổi được 1 lần.", primary "Gửi yêu cầu đổi"); cancel sheet as S05.03 with the single highlighted line "Hoàn 100% số đã trả", red "Huỷ và hoàn 100%", "Giữ lịch"; `#S05.05-studio` (booking card "{day} · thợ {name}", two `vblk` groups: member block with avatar, "Thợ {name}", note "Tính cho hồ sơ thợ", compact pad, comment "Nhận xét cho thợ"; studio block with seal, note "Tính cho studio", pad, five studio reason chips when brick, comment "Nhận xét cho studio"; primary "Gửi 2 đánh giá" enabled only when both blocks are complete, with the missing-block line).

- [ ] **Step 1: Contract check** (#130's `VerdictPad` API and review controller state; cancel sheet structure).
- [ ] **Step 2: Failing tests:** detail — "an unassigned studio booking shows Studio sẽ báo thợ chụp trước {deadline}"; "an assigned one shows the member card with %, shoots and studio, Xem hồ sơ opens /u/{assignee}"; "Xin đổi thợ (1 lần) opens S26.05; after sending it reads Đã xin đổi · chờ studio and is disabled"; "overdue (deadline passed, even before the sweep) shows Quá hạn, the warning, the reminded line and Huỷ và hoàn 100%"; "declined shows the studio's reason and the cancel link"; "expired and late reassign show their texts and the cancel link"; "Huỷ và hoàn 100% confirms in the 100% sheet and sends cancel_studio_fault"; "the footer reads Nhắn studio for studio bookings"; "individual bookings are unchanged". S26.05 — "shows the current member, optional reason, the two notes and the once line"; "Gửi yêu cầu đổi sends the note and closes with changeSent"; "conflict shows studioErr_conflict". S05.05 — "a studio booking shows two blocks with their notes"; "Gửi 2 đánh giá stays disabled until both blocks have a verdict and 10+ characters, and the line names the missing block"; "a studio brick needs one of the five studio reasons"; "submitting sends both blocks"; "after submitting, review mode shows both blocks read-only"; "an individual booking keeps the single block". Profile reviews — "a studio's review shows Chụp bởi {name}; a member's review from a studio booking shows Qua {studio}". `AssigneeCard` — "semantics read name, %, studio; buttons ≥ 48 dp". Each screen "fits 320dp at 1.3x text".
- [ ] **Step 3: Run** `flutter test --no-pub --timeout 60s test/features/booking` (then `test/features/studio`, `test/features/review`, `test/features/photographer_profile`, `test/core/widgets`) → fail.
- [ ] **Step 4: Implement**; arb keys; `flutter gen-l10n`.
- [ ] **Step 5: Run** `flutter analyze`; the five folders one at a time → pass.
- [ ] **Step 6: Commit** `feat(studio): assigned photographer on booking detail, change request, 100% cancel and two-sided review [#136]`.

### Task 10: Gallery, widget docs, specs, data model, ledger

**Files:**
- Modify: `scripts/tools/build_ui_components.py` (tiles for `MemberRow`, `MemberStrip`, `AssigneeCard`, with skeletons) → regenerate `docs/design/ui-components.html` (`python3 scripts/tools/build_ui_components.py`); `docs/superpowers/specs/components/shared-components.md` (three new entries + the widget ↔ screen table §6); `docs/superpowers/specs/2026-10-01-remaining-screens.md` (§2 S26.01–S26.05 "✅ đã làm (#136)", S03.01/S05.02/S05.05/S06.01/S09.02 notes); `docs/superpowers/specs/2026-10-06-studio-members-design.md` (§5.5 sweeps in `bookingClock`, §5.2 S27-ready assignment fields, §8 rules as built); `docs/superpowers/specs/data-model/domain-model.md` (`StudioRelation`, studio booking fields, `AssigneeKind`, `ReviewSubjectType`, new error codes) and `relational-schema.md` (target tables `studio_members`, `booking_assignments`, booking/photographer columns, `reviews.subject_type/subject_id` with key `(booking_id, subject_type)`, Firestore mapping rows); `docs/legal/terms-and-help-notes.md` (S1: the < 24 h booking grace of Decision 8); `docs/superpowers/handover/ledger-s26-studio-members.md` (complete)

- [ ] **Step 1:** Add the gallery tiles (API line, screens that use them, skeleton per the "per-component skeleton" rule) and regenerate; check the page opens (no Python error, the three anchors present).
- [ ] **Step 2:** Update the specs and data model; every quoted string equals `app_vi.arb` and the mock.
- [ ] **Step 3:** Ledger: rulings, deferred minors, skipped suites (rules and Functions integration written, not run; no device build), deploy order: (1) indexes before rules before Functions before the app (new queries on `bookings.assigneeId`, `studio_members`, `photographers.studioId`); (2) existing photographers get `nameKey` on their next profile or user write (`onUserWrite`/`onPhotographerWrite` heal) — S26.02 cannot find older dev accounts until then; (3) existing studio bookings created before this change have no studio fields and behave as individual bookings; (4) the S27 notes (Decision 9).
- [ ] **Step 4: Commit** `docs(spec): S26 gallery, widget docs, data model and ledger [#136]`.

## Deferred

- **S27 "Studio tuyển thợ"** (#151; collaborators who are not members, per-job acceptance, declared fee off the booking, `studio_collaborations`): not built here; the assignment model is ready (Decision 9: `assigneeKind`, `StudioRoster.relationOf` → `'collaborator'`, one `assignBooking` entry point).
- Assignee phone channels for the customer (spec §5.7, Needs the owner 3) — no control in the mock.
- Manager role, several owners, in-app money split between studio and member, several assignees per booking, customer pre-choosing a member, public violation counters or ranking by them (spec §9).
- Account deletion ending relations (`endedBy: system`, S22.02, #141).
- Showing both tags on the real-shoot post in S02.02 (Decision 22).
- `services/api` migration (phase 2, #90); staff screens for counters (phase 1.5, #83).
- Real payment intermediary for the studio-fault refunds (fake gateway now; #129).
