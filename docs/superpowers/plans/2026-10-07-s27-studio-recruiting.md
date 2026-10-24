# S27 · Studio tuyển thợ (recruit posts, collaborators, per-job offers, off-app pay record) Implementation Plan

> **Rules emulator tests (2026-10-02, user):** this plan changes `firestore.rules` and `firestore.indexes.json` and adds Functions. Write the rules tests; do not run them, CI runs them. Functions integration tests are not added (unit tests with in-memory fakes only). Record the skips in the ledger.

> **No battery/performance, device build or iOS steps** (standing rules in `RUN-ORDER.md`).

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

> **Detail level (user, 2026-10-02):** exact interfaces, tests listed by name with expected behaviour, sample code only for the parts easy to get wrong.

**Goal:** A verified studio posts free recruit notices that only provider accounts can read; photographers browse them in a "Tuyển thợ" tab of Công việc, and verified ones apply with a message and up to three portfolio posts. The studio accepts an applicant either as a per-job collaborator (CTV, non-exclusive) or as a member (S26 rules). The studio can also invite collaborators directly, assign a studio booking to an active collaborator with an agreed fee that the collaborator must accept within 6 hours, and record the fee it pays outside the app ("Đã trả / Đã nhận"), with flags and a temporary block when a studio does not pay. No money for collaborators flows through the app.

**Architecture:** Business rules in `packages/domain` (new `recruit*.ts`, `studio_collaboration.ts`, `collab_jobs.ts`, `recruit_areas.ts`; the contact filter shared with the jobs plan), behind one transaction port `RecruitStore`/`RecruitTx` plus the S26 assignment transaction port, with in-memory stores for tests. Firestore: `recruitPosts/{postId}`, `recruitApplications/{postId}_{uid}`, `studio_collaborations/{studioId}_{uid}` (+ `history/{id}`), `collab_jobs/{bookingId}_{uid}` (fee, offer and pay record, so the customer, who reads the booking document, never sees the studio's cost), server-only counters in `photographers/{uid}/private/recruit`, `staff_flags/{id}`. Every write is a callable, a trigger (`onRecruitPostCreated` fan-out, `onPhotographerWrite` match keys, `onBookingWrite` job sync and poaching flag) or the S26 15-minute job (no new schedule). Rules let only provider accounts (`users/{uid}.role == 'photographer'` and a `photographers/{uid}` doc) read recruit posts (R3). The app gets `lib/data/recruit/`, `lib/data/collab/`, feature folders `features/recruit/` (S27.01–S27.05) and `features/collab/` (S27.06–S27.07), and extends the S26 assign/invite sheets, S05.02, S06.01, S09.02, S03.01 and the chat list.

**Tech Stack:** TypeScript (domain, Functions v2 callables, `onDocumentCreated`, `onDocumentWritten`), Firestore rules and indexes; Flutter, Riverpod 3, go_router, `flutter_test`, fakes in `test/support/`.

**Spec:** `docs/superpowers/specs/2026-10-07-studio-recruiting-design.md` (authoritative, owner-approved: R1–R8, §3–§9); `docs/research/2026-10-07-studio-collaborators.md` (§3.3 design B+); `docs/superpowers/specs/2026-10-06-studio-members-design.md` (S26: T1–T12, §3.3 rules, §5.2 assignment, §5.5 job, §5.7 contact, §6 reviews); `2026-10-06-identity-verification-design.md` (`acceptingOrders`, `businessVerified`); `2026-10-07-google-cloud-costs.md` §14; main spec `2026-10-01-remaining-screens.md` §2, §3h; mock `docs/design/ui-mock.html` (S27 frames added by Task 1).

**Issue:** #151 (S27 · Studio tuyển thợ). **Execution wave:** 5 (cross-plan review 2026-10-07). **Blocked by:** #136 only (S26: studio members, `assignBooking`, two-sided reviews, studio day capacity; re-planned 2026-10-08). `BlockGate` and `orderBlocker` are #198's (`2026-10-08-n1-order-gate.md`, previously "#144"); #136 is blocked by #198, so they are on develop once #136 is. **Not blockers (create-if-absent, re-planned 2026-10-08):** #135 (S21: `vnDayKey`, `rate_limited`, `businessVerified`, `/verify/start`) and #139 (S15–S16: `contact_filter.ts` `findContactLeak`, `DomainError.field`, the S06.01 tabs). Whichever of them has landed is consumed as is; anything still missing is created here exactly as the owning plan specifies (Decisions 5, 10, 11, 20 and Contract → "Create-if-absent"), and the owner, landing later, reuses it. Already merged on develop: #130 (reviews: % cà chua), #138 (S17: the ten S27 notification hooks, copy and targets), #148 (S09: settings order).

**Branch:** `plan/151-s27-studio-recruiting` from `origin/develop` after #136 is merged; PR into `develop` titled `feat(recruit): S27 studio recruiting and per-job collaborators [#151]`.

**Corrections after execution (2026-10-24; detail in `docs/superpowers/handover/ledger-s27-studio-recruiting.md`):**
- Task 1 (mock frames, `ScreenCodes` S27.01–S27.07, spec §2 rows) was delivered by PR #187 (`9d1b7f43`); this unit ran Tasks 2–10.
- The milestone port `shotReleased(bookingId): boolean` is `shootMilestone(bookingId): 'released' | 'waiting' | 'refunded'` (pure `shootMilestoneState(payments)`); `refunded` ends the pay check with no pay record.
- `payPending` is keyed on `pay.checkAfter` (accepted, `payStatus none`, `checkAfter <= now`, pushed 6 h while the milestone waits), not `shootEndsAt`; its index is `(offerStatus, payStatus, pay.checkAfter)`.
- `takeDaily` / `isValidFee` / `Daily` / `NoticeDaily` are exported as `takeRecruitDaily` / `isValidRecruitFee` / `RecruitDaily` / `RecruitNoticeDaily`.
- `AppIcons.eventRepeat` was not added: `AppIcons.calendarRepeat` is the same glyph (`event_repeat`), and `app_icons_test` forbids two names for one glyph.

## Contract with existing code

Checked 2026-10-07 on `develop` (94bda85). Task 2 Step 1 (domain/Functions/rules) and the first step of Tasks 6–9 (app) re-check; adapt and ledger any difference. If a member named here does not exist, stop and report instead of guessing.

- Domain (`packages/domain/src`): `DomainError`, `ERROR_CODES` (`errors.ts`; today: `day_taken`, `phone_required`, `contact_locked`, `sold_out`, `deadline_passed`, `limit_exceeded`, `invalid_argument`, `permission_denied`, `not_found`, `conflict`, `price_changed`, `not_eligible`, `reauth_required`, `not_accepting_orders`); `acceptsOrders`, `ProviderOrderGate { acceptsOrders(photographerId) }` (`provider_orders.ts`, `booking_ports.ts`); `ProviderType`, `providerTypeOf` (`provider_type.ts`); `isId`, `newUlid`, `RandomBytes` (`ids.ts`); `Clock`, `IdGenerator` (`ports.ts`); notifications: `NOTIFICATION_TYPES` (`notification.ts`, `meta(category, tab, critical)`), `NotificationContent` union + `renderNotification` + `formatVnd` + `formatDayShortVi` (`notification_render.ts`), `notify(deps, req)` with `dedupeKey` / `groupKey` + `actor` (`notification_use_cases.ts`), `NotifyDeps`; chat: `CHAT_KINDS = ['inquiry','booking']`, `Chat` (`customerId`, `photographerId`, `readOnlyAt`), `roleInChat`, `assertCanSend`, `openInquiry` pattern (`open_inquiry.ts`), `ChatStore`/`ChatTx`; `getContactLink` + `bookingContactUnlocked` (`get_contact_link.ts`, `contact.ts`); memory stores refuse a read after a write inside a transaction (`memory_event_store.ts` pattern); `purity.test.ts` forbids Firebase/Node imports. No `contact_filter` yet (the jobs plan adds it, Decision 11), no area list, no recruit or collaboration code. S21 (#135, not a blocker) adds `vnDayKey` and `rate_limited`; if they are absent when this runs, this plan creates them (Contract → "Create-if-absent").
- Functions (`app_flutter/firebase/functions/src`): `CALLABLE_OPTIONS`, `TRIGGER_OPTIONS`, `SCHEDULE_OPTIONS` (`config.ts`); `toHttpsError` + `TRANSPORT_CODE` table (`callables/errors.ts`; a missing code fails to compile); the `requireUid` + `run(operation, fn)` pattern (`callables/award.ts`); `db()` (`infra/admin.ts`); `FirestoreProviderOrderGate` (`infra/booking_readers.ts`); `liveNotifyDeps()` (`infra/live_notification.ts`); `onPhotographerWrite` → `handlePhotographerEvent` → `syncAcceptingOrders(input, writer)` pattern (`triggers/photographer_write.ts`); `onBookingWrite` (`index.ts:170`, `triggers/booking_write.ts`); `sendMessage` callable (1-1 chats); seed `seed/fixtures.ts` (customers `LAN`, `MINH`; photographers `AN` verified individual Hà Nội portrait/wedding, `BINH` unverified Đà Nẵng, `CUC` verified **studio** TP.HCM wedding/family, `DUNG` verified artist Huế portrait) + `seed/README.md`, test `test/unit/seed_fixtures.test.ts`.
- Rules (`app_flutter/firebase/firestore.rules`): `signedIn()`, `isOwner(uid)`, `hasPhotographerRole(uid)` (uses `getAfter`, for writes), `users/{uid}.role ∈ {customer, photographer}` and the user may switch it any time (S09.02 "Chế độ"); `photographerServerFieldsUntouched()` list; `match /photographers/{uid}/private/{docId}` (owner reads every doc; client writes only `contact`); `bookings/{id}` read by `customerId`/`photographerId` (S26 adds `assigneeId`), `bookings/{id}/private/contact` (`isBookingContactUnlocked`); `chats/{chatId}` read by `members`; catch-all deny. Rules tests: one file `app_flutter/firebase/rules-test/rules.test.mjs`.
- Indexes: `app_flutter/firebase/firestore.indexes.json` (no recruit or collab entries).
- App data: `AreaOption` + `builtInAreas` (`lib/data/location/area.dart`; ids `hcm-q1`, `hcm-q3`, `hcm-q7`, `hcm-binh-thanh`, `hcm-thu-duc`, `hn-hoan-kiem`, `hn-ba-dinh`, `hn-cau-giay`, `dn-hai-chau`, `hue`, `da-lat`, `nha-trang`); `kSpecialties` (`lib/data/taxonomy/builtin_taxonomy.dart`, 14 ids); `ProviderType` (`lib/data/content/provider_type.dart`); `photographerSummaryFrom` / `PhotographerSummary` (`acceptingOrders`, `providerType`); `authStateProvider`, `currentProfileProvider` (`lib/data/auth/auth_providers.dart`); the award repository pattern (`lib/data/award/`: abstract repo + `Fake…` + `Firestore…` using `FirebaseFunctions.instanceFor(region: functionsRegion)` + `…Provider`); `ChatKind { inquiry, booking }` (`lib/data/chat/chat.dart`, unknown kind parses as inquiry); `notificationVisualOf` (`features/notifications/notification_visuals.dart`); `vnd_input.dart`, `vn_time.dart`, `text_fold.dart`, `format.dart` (`formatMoney`) in `lib/core/`.
- App features: `WorkScreen` S06.01 (`features/work/work_screen.dart`; no `SegmentedTabs` yet unless the jobs plan landed), `SettingsScreen` S09.02, `PhotographerProfileScreen` S03.01 (`ProfileHeader`), booking detail S05.02 (`features/booking/booking_detail_screen.dart`, routes `/b/:id…`), chat list S07.02 / chat screen S07.01, `lib/app/router.dart`.
- Core: `SegmentedTabs` (labels scale down), `AppButton.primary/outline/text/danger`, `showAppSheet`, `showConfirmSheet`, `AsyncView`, `EmptyState`, `SectionHeader`, `StatusBadge`, `AppChip`, `AppOptionTile`, `PostPickerGrid`, `CountdownText`, `ScreenCode`, `AppIcons` (has `work`, `store`, `people`, `payment`, `schedule`, `place`, `info`, `lock`, `camera`; **no** `handshake`, `campaign`, `eventRepeat`), `ScreenCodes` (`lib/core/screen_codes.dart`, `all` list; `test/core/screen_codes_test.dart` checks it against spec §2).

### What this plan expects from S26 (#136) — re-check at Task 2 Step 1

The S26 plan was written in parallel; it was asked to make the assignment model able to hold a non-member assignee with a relation kind. Find the real names in the merged code and use them; ledger every rename:

- `packages/domain/src/studio_membership.ts`: membership record (`studio_members` doc: `studioId`, `memberId`, `status`, `initiatedBy`, …), the rule checks behind "approve a join request" (`membership_conflict`, `cooldown`, `studio_full`), the VN-day helper and the daily-action counter. **Needed:** a pure checker this plan can call inside its own transaction, called `checkMemberActivation(state, now)` below. If S26 has the checks only inline in `respondJoinRequest`, extract them into an exported pure function in the same file without changing behaviour (S26 tests stay green).
- Booking fields: `isStudio`, `assigneeId`, `assignDeadline`, `assignments[]`, `assignOverdue`, and the relation kind on the booking and on each assignment entry (called `assigneeKind: 'member'` below). The assignment use case `assignBooking` and its transaction port (called `AssignTx` below), the calendar block it writes, the step that adds the assignee to the booking chat, the `booking_assigned` notification, and "Trả việc" (assignment returned).
- The S26 15-minute scheduled job (spec §5.5; an `onSchedule` export in `functions/src/index.ts`) and its handler.
- Contact: the predicate that opens the assignee's channels to the customer (in `getContactLink`) and the rules branch that lets the assignee read `bookings/{id}/private/contact`.
- App: the S26.04 assign sheet (`ScreenCodes.assignPhotographer`), the S26.02 invite sheet (`ScreenCodes.inviteMember`) and its provider search, the S05.02 "Thợ chụp cho bạn" block, the S06.01 label "Giao bởi {Studio}", the S09.02 rows "Thành viên studio" / "Studio của tôi".
- Error codes `membership_conflict`, `cooldown`, `studio_full`, `member_busy`, `rate_limited` (add any that S26 did not add, Decision 10).

**Create-if-absent (re-planned 2026-10-08; #135 and #139 are not blockers).** Task 2 Step 1 and the first step of Tasks 6–9 check each item; present → consume it unchanged; absent → do exactly this and ledger it:
- `vnDayKey(now: Date): string` (#135; UTC+7 calendar day `yyyy-MM-dd`): create it in `packages/domain/src/vn_day.ts`, exported from `index.ts`, with the test `vnDayKey: 16:59:59Z and 17:00:00Z are different VN days`. #135, landing later, imports it instead of defining a second one in `verification.ts`.
- Error code `rate_limited` (#135, also added by #136 if #135 had not): add it to `ERROR_CODES` with `TRANSPORT_CODE` `resource-exhausted`.
- `photographers/{uid}.businessVerified` (#135 writes it): read it as `=== true`; a missing field is `false` (so `collaboratorLimit(false)` = 5 and the S27.06 meta shows the unverified limit); nothing here writes it.
- `/verify/start` (#135's S21.02 route): the app already gates links to it with `verifyStartReadyProvider` (`lib/features/settings/settings_links.dart`, false until #135 flips it). Every "Xác minh để …" button of this plan follows that provider: when false, show the lock note and no button (tests pin both states); do not register the route here.
- `contact_filter.ts` `findContactLeak` and `DomainError.field` + `toHttpsError` `details.field` (#139): create them exactly as #139's Decision 15 and its regex sample specify (Decision 11).
- S06.01 `SegmentedTabs` (#139): if S06.01 has no segments, add them (Decision 20).

## Global Constraints

- Spec R1: "Chỉ **studio đã xác minh** (`acceptingOrders`) được đăng tin tuyển, **miễn phí**." R2: "**Mọi thợ** (kể cả chưa xác minh) xem được tin; **ứng tuyển cần đã xác minh** danh tính (S21)."
- Spec R3 (pinned by rules tests and Review Focus 1): "Tin chỉ hiện cho tài khoản có hồ sơ nhà cung cấp (thợ cá nhân, NAG, studio). Khách và người chưa đăng nhập không đọc được. Tin không lên feed, tìm kiếm của khách hay link chia sẻ." "Một tài khoản vừa là khách vừa là thợ chỉ thấy tin khi đang ở vai trò thợ."
- Spec R4: two kinds only, `collaborator` and `member`; never an employee kind.
- Spec R5: "**Tiền công CTV do studio trả ngoài app.** App chỉ ghi "Đã trả / Đã nhận", gắn cờ khi studio không trả và không bảo lãnh thù lao. Tiền booking vẫn 100% về studio theo hai mốc (S26 T11). Nền tảng không chi hộ, không khấu trừ thuế cho CTV." No `payments`, `refunds`, `ledger_entries` or payout write is added by this plan.
- Spec R6–R8: non-exclusive; both sides consent; each assigned shoot is accepted within 6 hours, declining is not a violation; customer contact opens to a collaborator only when assigned **and** accepted **and** paid, closes when replaced or 7 days after the booking is completed/cancelled.
- Brief ruling 5: anything that creates an assignment calls `ProviderOrderGate.acceptsOrders` (error `not_accepting_orders`, HTTP 403 in the API); here: posting (studio), applying, collaborating (both sides) and assigning to a collaborator.
- Blocks (cross-plan review finding 22): `applyToRecruitPost` (studio ↔ applicant), `inviteCollaborator` and `respondCollabInvite` (studio ↔ collaborator) call #198's `BlockGate.isBlockedEitherWay(a, b)` (`packages/domain/src/block_ports.ts`; live `liveBlockGate()` from `src/infra/live_safety.ts`, `FirestoreBlockGate` in `safety_firestore.ts`; tests `FakeBlockGate` from `fake_block_gate.ts`) → `blocked` (`failed-precondition`); collaborator assignment goes through S26's `assignBooking`, which already calls #198's `orderBlocker(deps, {customerId, providerId: assignee})` (`2026-10-08-n1-order-gate.md`; #129 did not build it, `2026-10-08-s04-reconciliation.md`) (customer ↔ collaborator), plus a studio ↔ collaborator `BlockGate` check here.
- Notifications: #138 owns the ten S27 types, their copy (this plan's table, moved there), targets and dedupe keys; this plan only calls #138's hooks (Decision 24).
- CLAUDE.md: business rules in `packages/domain` (no Firebase/Node imports, `purity.test.ts`); Functions thin, region `asia-southeast1`; Firebase only in `lib/data/**` adapters, `firebase_options.dart`, `main.dart`; ids opaque (`isId`), times UTC instants, money integer VND, enums as string codes (`data-model/README.md`); `AppColors`/`AppSpace`/`AppRadius`/`AppIcons` only; strings in `lib/l10n/app_vi.arb` + `flutter gen-l10n`; `package:photobooking/...` imports, features import `core/core.dart`; one `AppButton.primary` per screen (decline is never the gradient button; destructive confirmation is red inside a confirm sheet); `AsyncView` for every `AsyncValue`; every screen/sheet wrapped in `ScreenCode`.
- Commits: Conventional Commits, subject ends with `[#151]`, body ends with `Co-Authored-By: TonyH <thanhngochoangbk@gmail.com>` (never the Claude line).
- Env for Flutter commands (from `app_flutter/`): `source ../scripts/env.sh && export HOME="$PWD/../.home" && export PATH="$PWD/../.flutter/bin:$PATH"`.
- Tests: Flutter `flutter test --no-pub --timeout 60s <file or folder>`, one folder at a time (never the whole suite in one command); bounded pumps (`pump(Duration)` / `pumpAndSettle(timeout)`), no endless animation or timer left running (fake clocks for countdowns). Domain `cd packages/domain && npm test && npm run lint`. Functions `cd app_flutter/firebase/functions && npm test && npm run build`. Rules tests and Functions integration suites are written, not run (CI runs them).

## Decisions (where the spec is silent or specs conflict)

1. **Screen codes and routes.** `ScreenCodes.recruitList = 'S27.01'` (`/recruit`, also the "Tuyển thợ" segment of S06.01), `recruitDetail = 'S27.02'` (`/recruit/:postId`), `recruitApply = 'S27.03'` (sheet), `recruitEdit = 'S27.04'` (`/studio/recruit/new`, `/studio/recruit/:postId/edit`), `studioRecruit = 'S27.05'` (`/studio/recruit`, query `post`), `collaboration = 'S27.06'` (`/collab`, query `offer` opens S27.07), `collabOffer = 'S27.07'` (sheet). Variants in the mock: `S27.02-unverified`, `S27.06-me` (photographer view), `S26.02-collab`, `S26.04-collab`, `S05.02-studio-collab`.
2. **"Provider account" (R3)** = `users/{uid}.role == 'photographer'` **and** `photographers/{uid}` exists (any `providerType`, verified or not). A user in customer mode (role `customer`) is denied even when a `photographers/{uid}` doc exists from an earlier switch. Becoming a provider is self-service (S09.02), so R3 hides posts from customers; it is not a secret store. The same test gates the app: the S06.01 tab only exists for photographers; S03.01 "Đang tuyển" runs its count query only for provider viewers.
3. **Fee and pay are not on the booking (spec §5, §5.1 put `agreedFee` in `assignments[]` and `collaboratorPay` on the booking).** The customer reads the whole `bookings/{id}` document (rules cannot hide fields), so storing the fee there shows the studio's cost to the customer. Here the fee, the offer state and the pay record live in `collab_jobs/{bookingId}_{collaboratorId}` (read by the studio and that collaborator only). The booking keeps only `assigneeKind`, `assigneeAccepted` and, on each `assignments[]` entry, `assigneeKind`, `offerExpiresAt`, `acceptedAt?`, `declinedAt?`. Task 10 updates the spec text.
4. **Collaboration ids.** `studio_collaborations/{studioId}_{uid}` always holds the latest relationship. A new invite or acceptance after a terminal state copies the old document to `studio_collaborations/{studioId}_{uid}/history/{ulid}` and overwrites the main one in the same transaction. A deterministic id makes two concurrent invites collide inside one transaction instead of creating two records (the S26 "suffix" scheme cannot guarantee that on Firestore). Cooldown reads `endedAt` of the main document.
5. **Counters and quotas** live in the server-only doc `photographers/{uid}/private/recruit` (`RecruitCounters`, the owner can read it, rules already deny client writes to any private doc except `contact`): `openPostCount`, `postActions {day, count}`, `activeCollabCount`, `pendingInviteCount`, `collabActions {day, count}`, `openApplicationCount`, `applyActions {day, count}`, `notices {day, count}`, `unpaidFlags: Date[]`, `recruitBlockedUntil`. `day` is the Vietnam calendar day (`vnDayKey`, UTC+7; the helper S21 #135 adds — reuse it, do not define a second one; if #135 has not landed, create it once in `vn_day.ts`, Contract → "Create-if-absent"). Counted actions: studio posts = create + close (≤ 5/day); studio collaboration actions = invite, cancel invite, accept or decline an application, end (≤ 10/day); collaborator actions = end (≤ 5/day); applying ≤ 3/day; responding to an invite or an offer never counts. Every status change that leaves `open`, `applied`, `invited` or `active` decrements the matching counter in the same transaction, including sweeps (Review Focus 4).
6. **Area matching.** Photographers store `serviceArea {city, radiusKm, center?}`, not area ids. `packages/domain/src/recruit_areas.ts` mirrors `builtInAreas` (`{id, cityKey, lat, lng}`; a Dart test keeps the id lists equal). A provider's areas are every area whose centre is within `radiusKm` of `center`, else every area whose `cityKey` equals `recruitCityOf(serviceArea.city)` (named so it does not clash with the jobs plan's `cityKeyOf`, which folds without aliases; folded aliases: `hcm` ← "tp.hcm", "hcm", "ho chi minh", "sai gon"; `hn` ← "ha noi"; `dn` ← "da nang"; `hue`; `da-lat`; `nha-trang`). Studios get no areas (they never receive `recruit_post_new`).
7. **Match keys and filters.** `onPhotographerWrite` keeps the server-only field `photographers/{uid}.recruitMatchKeys` = `a=<area>|s=<specialty>` for every provider area × specialty (empty for studios and for `role != photographer`). Each post stores `matchKeys` (its areas × specialties, ≤ 20) and `filterKeys` (every non-empty combination of `k=<kind>`, `a=<area>`, `s=<specialty>` in that order, joined by `|`, ≤ 59), so any filter of S27.01 is one `array-contains` on `filterKeys` with one composite index. The list loads 20 posts per page with `get` (newest first); the client orders the loaded posts by match score (2 = an area and a specialty match the viewer, 1 = one of them, 0 = none) then date; "Xem thêm" appends and re-sorts. Score 2 shows the tag "Hợp với bạn".
8. **Fan-out.** `onRecruitPostCreated` (Firestore `onDocumentCreated` on `recruitPosts/{postId}`) queries `photographers where recruitMatchKeys array-contains-any post.matchKeys limit 200` (≤ 20 values, single-field index), drops the studio itself, then notifies each one through the daily cap (3 per provider per VN day, `notices` counter, checked and incremented in one transaction; capped ones are skipped, not queued). Renew and edit never re-notify. The 200 cap takes Firestore's default order; ranking is deferred.
9. **Closing and expiry cascade.** `closeRecruitPost` declines every `applied` application of the post (`recruit_application_result` declined); expiry (sweep) marks them `expired`. Both decrement each applicant's `openApplicationCount` and the post's `openPostCount` once. Pages of 200 per run; the sweep continues next run.
10. **Error codes.** Reuse S26's `membership_conflict`, `cooldown`, `studio_full`, `member_busy`, `rate_limited` (add the missing ones, `rate_limited` included when neither #135 nor #136 added it — create-if-absent —, with the same transport mapping S26 used: conflicts → `failed-precondition`, `rate_limited` → `resource-exhausted`). New: `collab_full` (`resource-exhausted`), `recruit_blocked` (`failed-precondition`). Contact in text → `invalid_argument` with a field (Decision 11). Daily quotas use #135's `rate_limited` while count limits use `limit_exceeded`: two names for two refusals, accepted (cross-plan review finding 42). Post not `open` → `deadline_passed`; a second application to the same post → `conflict`; 3 open posts or 10 open applications → `limit_exceeded`; offer past its expiry → `deadline_passed`; unverified caller or counterpart → `not_accepting_orders`; wrong provider type → `invalid_argument`.
11. **Contact filter = the jobs plan's (cross-plan review finding 2).** The job-posts plan (`2026-10-07-s15-s16-job-posts.md`, Decision 15; #139, not a blocker — it may land before or after this plan) creates `packages/domain/src/contact_filter.ts` with exactly `findContactLeak(text: string): 'phone' | 'email' | 'link' | 'zalo' | null` and an optional `field` on `DomainError` (`new DomainError('invalid_argument', 'title.contact')`, `toHttpsError` adds `details.field`). This plan consumes them and refuses any non-null result (`findContactLeak(text) !== null`); the bare word "zalo" is already its `'zalo'` result, so there is no local `hasZaloWord`. Create-if-absent: if #139 has not merged, create the module and `DomainError.field` (+ `toHttpsError` `details.field`) exactly as #139's Decision 15 and its regex sample specify; #139 then consumes them. Applied to post `title`, `requirements` and application `message`; refusal `invalid_argument` with field `title.contact`, `requirements.contact`, `message.contact`. Chat messages are not filtered by this plan (the booking chat a collaborator joins exists only after payment and acceptance, when contact is open anyway; Deferred).
12. **Who collaborates.** Studio: `providerType == 'studio'` and `acceptsOrders`. Collaborator: role `photographer`, `providerType ∈ {individual, artist}` and `acceptsOrders`. An active member of the same studio cannot become its collaborator (`membership_conflict`), and an active collaborator cannot be accepted as a member of the same studio until the collaboration is ended (`membership_conflict`; the S26 activation check gains this through the port, Task 3). Being a member of studio A and a collaborator of studio B is allowed (R6).
13. **Offers.** `assignBooking` with `assigneeKind: 'collaborator'` requires an `active` collaboration, studio ↔ collaborator not blocked either way (#198's `BlockGate`), `agreedFee` integer 1.000–100.000.000 and a multiple of 1.000, the collaborator free that day (same availability check as members) and `ProviderOrderGate`. `offerExpiresAt = now < assignDeadline ? min(now + 6 h, assignDeadline) : min(now + 6 h, startAt)`; if that is less than 15 minutes away → `deadline_passed` (assign a member instead). At offer time the booking gets `assigneeId`, `assigneeKind: 'collaborator'`, `assigneeAccepted: false`; no calendar block, no chat membership, no customer notification. On **accept**: availability re-checked (`day_taken` leaves the offer pending), calendar blocked, the booking moves from S26's `studio_day_load.unassignedIds` to `assignedIds` (Decision 26), chat joined, `assigneeAccepted: true`, customer gets S26's `booking_assigned`. On **decline or expiry**: `assigneeId`, `assigneeKind` cleared, `assigneeAccepted: false`, studio notified; S26's deadline and `assignOverdue` (T6, T8) carry on unchanged. A new `assignBooking` while an offer is pending marks the old job `replaced`.
14. **Collaborator returns an accepted job** ("Trả việc", S26): the job becomes `returned`, no pay record; the S26 flow continues.
15. **Pay record.** When the booking's first milestone is released to the studio (port `shotReleased(bookingId)`: the field the payments implementation writes; if milestone release is not implemented when this runs, "booking status past `shot`" — ledger which) the sweep sets `payStatus: 'due'`, `pay.dueAt = now`, and notifies the studio. Studio "Đã trả" → `paid_reported` (date ≤ today, method `bank|cash|other`); collaborator "Đã nhận" → `received`, "Chưa nhận" → `disputed`. A job still `due` 7 days after `dueAt`, or `disputed`, adds one entry to the studio's `unpaidFlags` (once per job per reason, `overdueFlaggedAt`/`disputeFlaggedAt`). Three entries within 90 days set `recruitBlockedUntil = now + 30 days` (Needs the owner 1): no new posts, invites or collaborator assignments (`recruit_blocked`); running posts and accepted jobs continue. Flags never clear automatically. A booking cancelled before the shoot cancels a pending/accepted job with no pay record.
16. **Collab chat.** Kind `collab`, id `collab_{studioId}_{collaboratorId}`, studio in the `customerId` slot and collaborator in the `photographerId` slot, so `roleInChat`, `assertCanSend` and `sendMessage` work unchanged (inquiry limits apply only to `inquiry`). Created lazily by the callable `openCollabChat` ("Nhắn tin" in S27.06) when the collaboration is `active` (or `ended` less than 30 days ago, read-only). `endCollaboration` sets `readOnlyAt = now` after commit; a later activation clears it. The app shows no `ContactDial` and no booking bar in collab chats.
17. **Reviews.** Unchanged S26 behaviour: the final assignee (a collaborator too) gets the photographer review with the tag "Qua {Studio}". Task 4 adds one regression test with `assigneeKind: 'collaborator'`. Studio↔collaborator reviews are out of scope (spec §10).
18. **Anti-poaching signal.** On a new non-studio booking (`onBookingWrite`, create), if its photographer had an accepted collab job with the same customer in the last 183 days and now has ≥ 2 personal bookings with that customer since that job, write `staff_flags/poach_{photographerId}_{customerId}` once (`{kind: 'collab_poaching', photographerId, customerId, studioId, jobIds, createdAt}`). Record only (spec §6).
19. **CSV export** is built on the device and copied to the clipboard with a SnackBar (no new package; events precedent for share). Columns: `Ngày chụp,Dịch vụ,Cộng tác viên,Thù lao,Trạng thái,Ngày trả,Cách trả`, one row per job whose `pay.dueAt` falls in the month (VN time). File saving/share is Deferred.
20. **S06.01 tab.** "Tuyển thợ" is the last `SegmentedTabs` option of S06.01. Create-if-absent: if S06.01 has no segments yet (jobs plan #139 not merged), add `SegmentedTabs` with "Hôm nay" and "Tuyển thợ"; the jobs plan inserts its two options between them. The segment renders the same `RecruitListView` as `/recruit` (ScreenCode `S27.01`). Studios see a bar icon "Tin tuyển của studio" → S27.05.
21. **Member-kind acceptance** runs inside the recruit transaction: `RecruitTx.getMemberState` returns what `checkMemberActivation` needs, the domain calls it (exact S26 errors, spec §3.3 "Lỗi nào thì báo đúng lỗi đó"), then `RecruitTx.putMember` writes the `studio_members` record with S26's mapping (`initiatedBy: 'member'`, `applicationId` extra field) and S26's counters. The S26 notification `studio_join_approved` is sent, plus `recruit_application_result`.
22. **Posts are edited only while `open`; `kind` is fixed after creation.** Renew: once, only while `open` and `renewed == false`, `expiresAt += 30 days`; an expired post cannot be renewed (post a new one). The studio snapshot (`name`, `avatarUrl`, `businessVerified`) is denormalised at create, update and renew.
23. **Withdraw** an application only while `applied`; it decrements the counter and does not refund the daily apply quota. One application per post forever (`conflict` after withdraw).
24. **Notifications through #138's hooks.** #138 owns the ten S27 types (category `jobs`, tab `activity`; `collab_assignment_offer` critical; `recruit_application_new` grouped per post), their copy (this plan's table, moved into #138's catalogue by the cross-plan review), dedupe keys and targets — `/recruit/:id`, `/studio/recruit?post=…`, `/collab`, `/collab?offer=…`, with those two query parameters explicitly allowed by #138's `safeTarget` (cross-plan review finding 29). This plan is the only emitter and adds no copy: use cases and triggers call #138's hooks after the commit (signatures in Contract). `notifyRecruitMatches` keeps its fan-out cap (3 per provider per VN day, 200 recipients) and calls `notifyRecruitPostNew` per recipient. Staff side of `collab_pay_disputed` is the flag only until S23 has an inbox (Deferred).
25. **Tax reminder** ("Khoản từ 5.000.000đ/lần…") shows in S27.06 (studio) while any due/reported job is ≥ 5.000.000₫ and the studio has not dismissed it; dismissal is remembered in SharedPreferences `collabTaxNoticeSeen:<uid>` (per-device convenience).
26. **Owner 2026-10-07: collaborators and studio capacity.** S26's capacity rule (S26 Decision 26: a studio takes one booking per free member per day) counts members only. An `active` collaborator adds no capacity before a booking exists, and a pending offer does not either: the booking stays in `studio_day_load.unassignedIds` until the collaborator accepts; on acceptance it moves to `assignedIds` and the collaborator's own day is booked, exactly like an assigned member. So a studio whose members are all busy cannot take a new booking on the strength of its collaborators; collaborators let it staff bookings it has already taken. A declined or expired offer leaves the booking unassigned (capacity unchanged).

## Needs the owner

1. How long is the temporary block after 3 unpaid flags in 90 days? **Default: 30 days**, staff can lift it earlier in the console.
2. Providers without a map centre are matched to areas by the city text of their service area (TP.HCM → every HCM district). **Default: yes**, until the location work stores a centre.
3. A collaborator who wants to become a member of the same studio must end the collaboration first. **Default: yes** (refused with a clear message); alternative: auto-end when no jobs are open.
4. The 200-recipient cap per new post takes an arbitrary subset when more providers match. **Default: accept for phase 1**; rank by profile completeness later.

## Contract

### Firestore data (all written only by Functions)

`recruitPosts/{postId}` (ULID):
`studioId`, `studio: {name, avatarUrl|null, businessVerified}`, `kind` (`collaborator|member`), `title` (8–80), `specialties[]` (1–4, `kSpecialties` ids), `areas[]` (1–5, area ids), `frequency` (`occasional|weekly|seasonal`), `feeHint` (`{type: 'per_shoot', amount}` | `{type: 'negotiable'}`), `requirements` (0–600), `status` (`open|closed|expired`), `renewed`, `applicationCount`, `matchKeys[]`, `filterKeys[]`, `createdAt`, `updatedAt`, `expiresAt`, `closedAt|null`.

`recruitApplications/{postId}_{uid}`:
`postId`, `studioId`, `applicantId`, `kind`, `postTitle`, `applicant: {name, avatarUrl|null}`, `status` (`applied|accepted|declined|withdrawn|expired`), `message` (0–400), `samplePostIds[]` (0–3, the applicant's own posts), `termsAcceptedAt|null` (collaborator kind: required), `createdAt`, `expiresAt` (+7 days), `respondedAt|null`.

`studio_collaborations/{studioId}_{uid}` (+ `history/{ulid}` copies):
`studioId`, `collaboratorId`, `studio: {name, avatarUrl|null}`, `collaborator: {name, avatarUrl|null}`, `status` (`invited|requested|active|declined|cancelled|expired|ended`; `requested` is reserved, no callable creates it — Deferred), `initiatedBy` (`studio|collaborator|application`), `applicationId|null`, `defaultFee|null`, `termsAcceptedAt|null`, `createdAt`, `expiresAt` (+7 days), `activeAt|null`, `endedAt|null`, `endedBy` (`studio|collaborator|system|null`), `updatedAt`.

`collab_jobs/{bookingId}_{collaboratorId}`:
`bookingId`, `studioId`, `collaboratorId`, `customerId`, `studioName`, `collaboratorName`, `shoot: {day, start, end, serviceName, placeName}`, `shootEndsAt`, `agreedFee`, `offerStatus` (`pending|accepted|declined|expired|replaced|returned|cancelled`), `offerAt`, `offerExpiresAt`, `acceptedAt|null`, `declinedAt|null`, `closedAt|null` (booking completed/cancelled), `payStatus` (`none|due|paid_reported|received|disputed`), `pay: {amount, dueAt|null, paidOn|null (yyyy-MM-dd), method|null (bank|cash|other), reportedAt|null, receivedAt|null, disputedAt|null, overdueFlaggedAt|null, disputeFlaggedAt|null}`, `createdAt`, `updatedAt`.

`photographers/{uid}/private/recruit` (`RecruitCounters`, Decision 5). `photographers/{uid}.recruitMatchKeys[]` (server-only, Decision 7). `staff_flags/{id}` (Decision 18, server-only, no client read). `bookings/{id}` gains `assigneeKind` (`member|collaborator`, S26 writes `member`), `assigneeAccepted: bool`; assignment entries gain `assigneeKind`, `offerExpiresAt?`, `acceptedAt?`, `declinedAt?`. `chats/collab_{studioId}_{uid}`: `kind: 'collab'`.

### Domain (`packages/domain/src`)

```ts
// contact_filter.ts (created by the jobs plan #139, consumed here; Decision 11)
export function findContactLeak(text: string): 'phone' | 'email' | 'link' | 'zalo' | null;
// errors.ts: class DomainError { constructor(readonly code: ErrorCode, readonly field?: string) }

// recruit_areas.ts
export interface RecruitArea { readonly id: string; readonly cityKey: string; readonly lat: number; readonly lng: number }
export const RECRUIT_AREAS: readonly RecruitArea[];             // same ids, order and centres as builtInAreas
export function recruitCityOf(city: string): string | null;     // 'hcm' | 'hn' | 'dn' | 'hue' | 'da-lat' | 'nha-trang' | null
export function recruitAreasOf(area: { city?: unknown; radiusKm?: unknown; center?: { lat: number; lng: number } | null } | null): string[];
export function recruitMatchKeysOf(p: { role: unknown; providerType: unknown; serviceArea: unknown; specialties: readonly string[] }): string[];

// recruit.ts
export const RECRUIT_KINDS = ['collaborator', 'member'] as const;
export const RECRUIT_FREQUENCIES = ['occasional', 'weekly', 'seasonal'] as const;
export const RECRUIT_POST_STATUSES = ['open', 'closed', 'expired'] as const;
export const APPLICATION_STATUSES = ['applied', 'accepted', 'declined', 'withdrawn', 'expired'] as const;
export const RECRUIT_TITLE_MIN = 8, RECRUIT_TITLE_MAX = 80, RECRUIT_REQUIREMENTS_MAX = 600,
  RECRUIT_SPECIALTIES_MAX = 4, RECRUIT_AREAS_MAX = 5, RECRUIT_POST_DAYS = 30, MAX_OPEN_POSTS = 3,
  STUDIO_POST_DAILY_ACTIONS = 5, APPLICATION_MESSAGE_MAX = 400, APPLICATION_SAMPLES_MAX = 3,
  APPLICATION_TTL_DAYS = 7, MAX_OPEN_APPLICATIONS = 10, APPLY_DAILY = 3, RECRUIT_NOTICES_DAILY = 3,
  RECRUIT_FANOUT_MAX = 200, FEE_MIN = 1_000, FEE_MAX = 100_000_000, FEE_STEP = 1_000;
export type FeeHint = { readonly type: 'per_shoot'; readonly amount: number } | { readonly type: 'negotiable' };
export interface RecruitPost { /* fields above; Date for instants */ }
export interface RecruitApplication { /* fields above */ }
export interface RecruitCounters { /* Decision 5; Daily = { day: string; count: number } */ }
export const EMPTY_COUNTERS: RecruitCounters;
export function takeDaily(d: Daily | null, at: Date, max: number): Daily; // throws rate_limited when full
export function recruitFilterKey(f: { kind?: string; area?: string; specialty?: string }): string; // 'k=…|a=…|s=…'
export function recruitFilterKeys(p: { kind: string; areas: readonly string[]; specialties: readonly string[] }): string[];
export function recruitMatchKeys(areas: readonly string[], specialties: readonly string[]): string[];
export function validateRecruitPostInput(raw: unknown, mode: 'create' | 'update'): RecruitPostFields; // invalid_argument (with field; '<field>.contact' for contact info)

// recruit_ports.ts
export interface ProviderFacts { readonly uid: string; readonly role: string | null; readonly providerType: ProviderType;
  readonly acceptsOrders: boolean; readonly businessVerified: boolean; readonly name: string; readonly avatarUrl: string | null; }
export interface RecruitTx {
  getPost(id: string): Promise<RecruitPost | null>;
  getApplication(postId: string, uid: string): Promise<RecruitApplication | null>;
  getCollaboration(studioId: string, uid: string): Promise<Collaboration | null>;
  getCounters(uid: string): Promise<RecruitCounters>;               // EMPTY_COUNTERS when missing
  activeMembershipStudioOf(uid: string): Promise<string | null>;     // S26 studio_members, status active
  getMemberState(studioId: string, uid: string): Promise<MemberActivationState>; // S26 shape (Decision 21)
  getCollabJob(bookingId: string, uid: string): Promise<CollabJob | null>;
  putPost(p: RecruitPost): void; putApplication(a: RecruitApplication): void;
  putCollaboration(c: Collaboration): void; archiveCollaboration(previous: Collaboration, historyId: string): void;
  putCounters(uid: string, c: RecruitCounters): void; putMember(m: MemberActivation): void; putCollabJob(j: CollabJob): void;
}
export interface RecruitStore {
  runTransaction<T>(fn: (tx: RecruitTx) => Promise<T>): Promise<T>;
  appliedOf(postId: string, limit: number): Promise<RecruitApplication[]>;
  duePosts(now: Date, limit: number): Promise<RecruitPost[]>;               // open, expiresAt <= now
  dueApplications(now: Date, limit: number): Promise<RecruitApplication[]>; // applied, expiresAt <= now
  dueInvites(now: Date, limit: number): Promise<Collaboration[]>;           // invited, expiresAt <= now
  dueOffers(now: Date, limit: number): Promise<CollabJob[]>;                // pending, offerExpiresAt <= now
  payPending(now: Date, limit: number): Promise<CollabJob[]>;               // accepted, payStatus none, shootEndsAt <= now
  overduePay(cutoff: Date, limit: number): Promise<CollabJob[]>;            // due, pay.dueAt <= cutoff, overdueFlaggedAt null
  openJobCount(studioId: string, uid: string): Promise<number>;             // pending|accepted and closedAt null
  matchingProviders(matchKeys: readonly string[], limit: number): Promise<string[]>;
}
export interface RecruitDeps {
  readonly store: RecruitStore; readonly people: { provider(uid: string): Promise<ProviderFacts | null> };
  readonly orders: ProviderOrderGate; readonly blocks: BlockGate; /* #198; liveRecruitDeps() sets liveBlockGate() */ readonly posts: { ownedBy(uid: string, postIds: readonly string[]): Promise<boolean> };
  readonly milestones: { shotReleased(bookingId: string): Promise<boolean> };
  readonly notify: NotifyDeps; readonly clock: Clock; readonly ids: IdGenerator;
}

// recruit_use_cases.ts — all take (deps, callerId, raw)
createRecruitPost → { postId }; updateRecruitPost → void; closeRecruitPost → void; renewRecruitPost → { expiresAt: Date };
applyToRecruitPost → { applicationId }; withdrawRecruitApplication → void;
respondRecruitApplication → { status: 'accepted' | 'declined' };
// recruit_notify.ts
export function notifyRecruitMatches(deps: RecruitDeps, postId: string): Promise<{ sent: number; capped: number }>;

// studio_collaboration.ts
export const COLLAB_STATUSES = ['invited', 'requested', 'active', 'declined', 'cancelled', 'expired', 'ended'] as const;
export const COLLAB_INVITE_TTL_DAYS = 7, COLLAB_REINVITE_DAYS = 3, MAX_COLLABS_PER_COLLABORATOR = 5,
  MAX_COLLABORATORS_UNVERIFIED_BUSINESS = 5, MAX_COLLABORATORS_VERIFIED_BUSINESS = 50, MAX_PENDING_COLLAB_INVITES = 5,
  STUDIO_COLLAB_DAILY_ACTIONS = 10, COLLABORATOR_DAILY_ACTIONS = 5;
export interface Collaboration { /* fields above */ }
export function collaboratorLimit(businessVerified: boolean): number;
// collab_use_cases.ts — (deps: RecruitDeps, callerId, raw)
inviteCollaborator({collaboratorId, defaultFee?}); cancelCollabInvite({collaboratorId});
respondCollabInvite({studioId, accept, acceptTerms}); endCollaboration({studioId} | {collaboratorId});
setCollabDefaultFee({collaboratorId, defaultFee: number | null});
// shared by respondRecruitApplication and respondCollabInvite:
export function activateCollaboration(tx: RecruitTx, input: { studio: ProviderFacts; collaborator: ProviderFacts;
  initiatedBy: 'studio' | 'application'; applicationId: string | null; termsAcceptedAt: Date; now: Date; ids: IdGenerator }): Promise<Collaboration>;

// collab_jobs.ts
export const OFFER_HOURS = 6, OFFER_MIN_MINUTES = 15, PAY_OVERDUE_DAYS = 7, UNPAID_FLAGS_TO_BLOCK = 3,
  UNPAID_WINDOW_DAYS = 90, RECRUIT_BLOCK_DAYS = 30, CONTACT_CLOSE_DAYS = 7, POACH_WINDOW_DAYS = 183, POACH_THRESHOLD = 2;
export interface CollabJob { /* fields above */ }
export function offerExpiry(now: Date, assignDeadline: Date, startAt: Date): Date | null;   // null → deadline_passed
export function collaboratorContactOpen(b: { assigneeKind?: string; assigneeAccepted?: boolean; status: string;
  completedAt: Date | null; cancelledAt: Date | null }, now: Date): boolean;
export function addUnpaidFlag(c: RecruitCounters, now: Date): RecruitCounters;   // prunes > 90 d, sets recruitBlockedUntil at 3
export function isRecruitBlocked(c: RecruitCounters, now: Date): boolean;
// assignment extension (S26 module): assignBooking input gains assigneeKind + agreedFee; new use case
respondCollabOffer(deps: AssignDeps & { recruit: RecruitDeps }, callerId, {bookingId, accept}) → { offerStatus };
reportCollabPaid(deps: RecruitDeps, callerId, {bookingId, collaboratorId, paidOn, method}); confirmCollabPay(deps, callerId, {bookingId, received});
export function poachingSignal(input: { jobs: readonly CollabJob[]; personalBookingsSince: (since: Date) => number; now: Date }): CollabJob[] | null;
// recruit_sweeps.ts
export function runRecruitSweeps(deps: RecruitDeps & { assign: AssignDeps }): Promise<RecruitSweepResults>;
// { postsExpired, applicationsExpired, invitesExpired, offersExpired, payDue, payFlagged }
```

Notifications (consumed from #138, `packages/domain/src/notification_hooks.ts`; Decision 24). The ten types, their copy (the table below, moved into #138's catalogue unchanged), category `jobs`/tab `activity`, `collab_assignment_offer` critical, dedupe keys and targets are #138's; signatures quoted so each task has them:

```ts
export function notifyRecruitPostNew(deps: NotifyDeps, e: { recipientId: string; studioId: string; postId: string; title: string }): Promise<NotifyResult>;
export function notifyRecruitApplicationNew(deps: NotifyDeps, e: { studioId: string; postId: string; title: string; applicantId: string }): Promise<NotifyResult>; // grouped recruit:{postId}:apps
export function notifyRecruitApplicationResult(deps: NotifyDeps, e: { applicantId: string; studioId: string; postId: string; title: string; outcome: 'collaborator' | 'member' | 'declined' | 'expired' }): Promise<NotifyResult>;
export function notifyCollabInvite(deps: NotifyDeps, e: { collaboratorId: string; studioId: string; invitedAt: string }): Promise<NotifyResult>;
export function notifyCollabInviteResult(deps: NotifyDeps, e: { studioId: string; collaboratorId: string; invitedAt: string; outcome: 'accepted' | 'declined' | 'expired' }): Promise<NotifyResult>;
export function notifyCollabAssignmentOffer(deps: NotifyDeps, e: { collaboratorId: string; studioId: string; bookingId: string; service: string; day: string; start: string; fee: number; deadline: string }): Promise<NotifyResult>;
export function notifyCollabAssignmentResult(deps: NotifyDeps, e: { studioId: string; collaboratorId: string; bookingId: string; outcome: 'accepted' | 'declined' | 'expired'; service: string; day: string; start: string; deadline: string }): Promise<NotifyResult>;
export function notifyCollabPayDue(deps: NotifyDeps, e: { studioId: string; collaboratorId: string; bookingId: string; amount: number; service: string; day: string }): Promise<NotifyResult>;
export function notifyCollabPayReported(deps: NotifyDeps, e: { collaboratorId: string; studioId: string; bookingId: string; amount: number; method: 'bank' | 'cash' | 'other' }): Promise<NotifyResult>;
export function notifyCollabPayDisputed(deps: NotifyDeps, e: { studioId: string; collaboratorId: string; bookingId: string; amount: number; service: string; day: string }): Promise<NotifyResult>;
```

Copy as moved to #138 (listed for this plan's tests only):

| type | content fields | title | body |
|---|---|---|---|
| `recruit_post_new` | studio, title | "Tin tuyển hợp với bạn" | "{studio}: {title}" |
| `recruit_application_new` (grouped) | name, title, count | "Ứng viên mới" | count 1: "{name} ứng tuyển “{title}”"; more: "{count} người ứng tuyển “{title}”" |
| `recruit_application_result` | outcome `collaborator\|member\|declined\|expired`, studio, title | collaborator/member: "Studio đã nhận bạn"; declined: "Ứng tuyển chưa được nhận"; expired: "Ứng tuyển đã hết hạn" | collaborator: "{studio} nhận bạn làm cộng tác viên."; member: "{studio} nhận bạn vào studio."; declined: "{studio} chưa nhận ứng tuyển “{title}”."; expired: "Ứng tuyển “{title}” đã hết hạn sau 7 ngày." |
| `collab_invite` | studio | "Lời mời cộng tác" | "{studio} mời bạn cộng tác theo việc. Hết hạn sau 7 ngày." |
| `collab_invite_result` | outcome `accepted\|declined\|expired`, name | "Lời mời cộng tác" | accepted: "{name} đã nhận lời cộng tác."; declined: "{name} đã từ chối lời mời cộng tác."; expired: "Lời mời cộng tác gửi {name} đã hết hạn." |
| `collab_assignment_offer` | studio, service, day, start, fee, deadline | "Việc cộng tác mới" | "{studio} · {service}, {day} · {start}. Thù lao {fee}. Trả lời trước {deadline}." |
| `collab_assignment_result` | outcome `accepted\|declined\|expired`, name, service, day, start, deadline | accepted: "{name} đã nhận việc"; declined: "{name} từ chối việc"; expired: "{name} chưa trả lời" | accepted: "{service}, {day} · {start}."; declined/expired: "Giao người khác trước {deadline}." |
| `collab_pay_due` | name, amount, service, day | "Đến hạn trả thù lao" | "Trả {name} {amount} cho buổi {service} {day}." |
| `collab_pay_reported` | studio, amount, method | "Studio báo đã trả thù lao" | "{studio} báo đã trả {amount} ({method}). Bấm Đã nhận hoặc Chưa nhận." (method: "chuyển khoản" / "tiền mặt" / "cách khác") |
| `collab_pay_disputed` | name, amount, service, day | "Cộng tác viên chưa nhận thù lao" | "{name} báo chưa nhận {amount} cho buổi {service} {day}." |

Targets: `recruit_post_new`, `recruit_application_result` → `/recruit/{postId}`; `recruit_application_new` → `/studio/recruit?post={postId}`; `collab_invite`, `collab_invite_result`, `collab_pay_*` → `/collab`; `collab_assignment_offer` → `/collab?offer={bookingId}`; `collab_assignment_result` → `/b/{bookingId}`. Dedupe keys `<type>:<id>[:<outcome>]` (#138's). All four target shapes, including the `post` and `offer` query parameters, are allowlisted by #138.

### Callables (`asia-southeast1`, `CALLABLE_OPTIONS`, thin: auth → domain → `toHttpsError`)

| name | input | output | errors |
|---|---|---|---|
| `createRecruitPost` | `{kind, title, specialties, areas, frequency, feeHint, requirements}` | `{postId}` | `not_accepting_orders`, `invalid_argument` (+ `details.field`), `limit_exceeded`, `rate_limited`, `recruit_blocked` |
| `updateRecruitPost` | `{postId, title, specialties, areas, frequency, feeHint, requirements}` | `{}` | `not_found`, `permission_denied`, `deadline_passed`, `invalid_argument` (+ `details.field`) |
| `closeRecruitPost` | `{postId}` | `{}` | `not_found`, `permission_denied`, `deadline_passed`, `rate_limited` |
| `renewRecruitPost` | `{postId}` | `{expiresAt}` | `not_found`, `permission_denied`, `deadline_passed`, `conflict` (already renewed) |
| `applyToRecruitPost` | `{postId, message, samplePostIds, acceptTerms}` | `{applicationId}` | `not_accepting_orders`, `invalid_argument` (+ `details.field`), `deadline_passed`, `membership_conflict`, `conflict`, `limit_exceeded`, `rate_limited` |
| `withdrawRecruitApplication` | `{postId}` | `{}` | `not_found`, `deadline_passed` |
| `respondRecruitApplication` | `{postId, applicantId, accept}` | `{status}` | `not_found`, `permission_denied`, `deadline_passed`, `rate_limited`, `recruit_blocked`, `not_accepting_orders`, `membership_conflict`, `cooldown`, `studio_full`, `collab_full` |
| `inviteCollaborator` | `{collaboratorId, defaultFee?}` | `{}` | `not_accepting_orders`, `invalid_argument`, `membership_conflict`, `cooldown`, `collab_full`, `rate_limited`, `recruit_blocked`, `conflict` (already invited/active) |
| `cancelCollabInvite` | `{collaboratorId}` | `{}` | `not_found`, `rate_limited` |
| `respondCollabInvite` | `{studioId, accept, acceptTerms}` | `{status}` | `not_found`, `deadline_passed`, `invalid_argument` (accept without terms), `not_accepting_orders`, `membership_conflict`, `collab_full` |
| `endCollaboration` | `{studioId}` or `{collaboratorId}` | `{}` | `not_found`, `member_busy`, `rate_limited` |
| `setCollabDefaultFee` | `{collaboratorId, defaultFee}` | `{}` | `not_found`, `invalid_argument` |
| `respondCollabOffer` | `{bookingId, accept}` | `{offerStatus}` | `not_found`, `permission_denied`, `deadline_passed`, `day_taken` |
| `reportCollabPaid` | `{bookingId, collaboratorId, paidOn, method}` | `{}` | `not_found`, `permission_denied`, `conflict` (not `due`/`disputed`), `invalid_argument` |
| `confirmCollabPay` | `{bookingId, received}` | `{}` | `not_found`, `permission_denied`, `conflict` (not `paid_reported`/`due`) |
| `openCollabChat` | `{studioId}` or `{collaboratorId}` | `{chatId}` | `not_found`, `not_eligible` |
| `assignBooking` (S26, extended) | `+ {assigneeKind?: 'member'\|'collaborator', agreedFee?}` | unchanged | `+ recruit_blocked`, `deadline_passed`, `not_accepting_orders`, `invalid_argument` |

Triggers: `onRecruitPostCreated` (`recruitPosts/{postId}`, create → `notifyRecruitMatches`), `onPhotographerWrite` (+ `syncRecruitMatchKeys`), `onBookingWrite` (+ `syncCollabJob`, `flagPoaching`). Scheduled: none new; the S26 15-minute job also calls `handleRecruitSweeps()`.

### Rules (Task 5 writes them; sample in Task 5)

`recruitPosts`: read if `isProviderAccount()`; `recruitApplications`: read if `applicantId == uid || studioId == uid`; `studio_collaborations` (+ `history`): read if `studioId == uid || collaboratorId == uid`; `collab_jobs`: read if `studioId == uid || collaboratorId == uid`; `staff_flags`: none; every write `false`. `photographers/{uid}`: `recruitMatchKeys` added to `photographerServerFieldsUntouched()`. `bookings/{id}/private/contact`: the assignee branch from S26 additionally requires `assigneeKind != 'collaborator' || assigneeAccepted == true` and closes 7 days after `completedAt`/`cancelledAt`.

### Indexes (`firestore.indexes.json`)

`recruitPosts`: (`status` ASC, `createdAt` DESC); (`status` ASC, `filterKeys` CONTAINS, `createdAt` DESC); (`studioId` ASC, `status` ASC, `createdAt` DESC); (`studioId` ASC, `createdAt` DESC); (`status` ASC, `expiresAt` ASC). `recruitApplications`: (`studioId` ASC, `postId` ASC, `status` ASC, `createdAt` DESC); (`applicantId` ASC, `createdAt` DESC); (`status` ASC, `expiresAt` ASC); (`postId` ASC, `status` ASC). `studio_collaborations`: (`studioId` ASC, `status` ASC, `updatedAt` DESC); (`collaboratorId` ASC, `status` ASC, `updatedAt` DESC); (`status` ASC, `expiresAt` ASC). `collab_jobs`: (`studioId` ASC, `updatedAt` DESC); (`collaboratorId` ASC, `updatedAt` DESC); (`studioId` ASC, `collaboratorId` ASC, `offerStatus` ASC); (`offerStatus` ASC, `offerExpiresAt` ASC); (`offerStatus` ASC, `payStatus` ASC, `shootEndsAt` ASC); (`payStatus` ASC, `pay.dueAt` ASC); (`studioId` ASC, `pay.dueAt` ASC); (`collaboratorId` ASC, `customerId` ASC, `acceptedAt` DESC). `photographers.recruitMatchKeys` uses the automatic single-field array index.

### App (Dart)

```dart
// lib/data/recruit/recruit_post.dart
enum RecruitKind { collaborator, member }           // .code, fromCode (unknown → null: row dropped)
enum RecruitFrequency { occasional, weekly, seasonal }
enum RecruitPostStatus { open, closed, expired }
enum ApplicationStatus { applied, accepted, declined, withdrawn, expired }
sealed class FeeHint { const FeeHint(); }           // PerShootFee(int amount) | NegotiableFee()
class RecruitPost { id, studioId, studioName, studioAvatarUrl, studioBusinessVerified, kind, title, specialties,
  areas, frequency, fee, requirements, status, renewed, applicationCount, matchKeys, createdAt, expiresAt; }
class RecruitApplication { id, postId, studioId, applicantId, kind, postTitle, applicantName, applicantAvatarUrl,
  status, message, samplePostIds, createdAt, expiresAt, respondedAt; }
class RecruitCounters { openPostCount, postActionsLeft(now), activeCollabCount, pendingInviteCount, collabActionsLeft(now),
  openApplicationCount, recruitBlockedUntil; }
class RecruitFilter { RecruitKind? kind; String? area; String? specialty; String? studioId; }
String recruitFilterKey({RecruitKind? kind, String? area, String? specialty});   // mirror of the domain
int recruitMatchScore(RecruitPost p, List<String> viewerMatchKeys);              // 0, 1, 2
enum RecruitErrorCode { notAcceptingOrders, invalidArgument, limitExceeded, rateLimited, recruitBlocked,
  deadlinePassed, conflict, membershipConflict, cooldown, studioFull, collabFull, memberBusy, dayTaken, notFound,
  permissionDenied, notEligible, network, unknown }
class RecruitError implements Exception { final RecruitErrorCode code; final String? field; }   // field from details.field; '<name>.contact' = contact info

// lib/data/recruit/recruit_repository.dart (+ FakeRecruitRepository), firestore_recruit_repository.dart
abstract class RecruitRepository {
  Future<RecruitPage> list(RecruitFilter filter, {Object? after, int limit = 20});   // get, newest first
  Future<RecruitPost?> get(String postId);
  Future<int> openCountOf(String studioId);                                          // count() aggregation
  Stream<List<RecruitPost>> watchStudioPosts(String studioId, {int limit = 10});
  Future<List<RecruitApplication>> applicantsOf(String studioId, String postId, {int limit = 30});
  Stream<RecruitApplication?> watchMyApplication(String postId, String uid);
  Stream<RecruitCounters> watchCounters(String uid);
  Stream<ProviderFacts?> watchMyProviderFacts(String uid);  // role, providerType, acceptingOrders, businessVerified, recruitMatchKeys
  Future<String> create(RecruitDraft d); Future<void> update(String postId, RecruitDraft d);
  Future<void> close(String postId); Future<DateTime> renew(String postId);
  Future<void> apply(String postId, {required String message, required List<String> samplePostIds, required bool acceptTerms});
  Future<void> withdraw(String postId);
  Future<void> respond(String postId, String applicantId, {required bool accept});
}
// lib/data/collab/collaboration.dart, collab_repository.dart (+ FakeCollabRepository), firestore_collab_repository.dart, collab_csv.dart
enum CollabStatus { invited, requested, active, declined, cancelled, expired, ended }
enum OfferStatus { pending, accepted, declined, expired, replaced, returned, cancelled }
enum PayStatus { none, due, paidReported, received, disputed }     // codes: none, due, paid_reported, received, disputed
enum CollabPayMethod { bank, cash, other } // not `PayMethod`: core/payments.dart already declares that name (checked 2026-10-08 on develop 87d8187) (cross-plan review finding 9)
class Collaboration { studioId, collaboratorId, studioName, studioAvatarUrl, collaboratorName, collaboratorAvatarUrl, status,
  defaultFee, activeAt, expiresAt, endedAt; }
class CollabJob { bookingId, studioId, collaboratorId, studioName, collaboratorName, day, start, end, serviceName, placeName,
  agreedFee, offerStatus, offerExpiresAt, acceptedAt, payStatus, payDueAt, paidOn, payMethod, reportedAt; }
abstract class CollabRepository {
  Stream<List<Collaboration>> watchAsStudio(String studioId);          // invited | active, ≤ 60
  Stream<List<Collaboration>> watchAsCollaborator(String uid);         // invited | active, ≤ 20
  Stream<List<CollabJob>> watchJobsAsStudio(String studioId, {int limit = 50});
  Stream<List<CollabJob>> watchJobsAsCollaborator(String uid, {int limit = 50});
  Future<List<CollabJob>> jobsDueInMonth(String studioId, int year, int month);
  Future<void> invite(String collaboratorId, {int? defaultFee}); Future<void> cancelInvite(String collaboratorId);
  Future<void> respondInvite(String studioId, {required bool accept, required bool acceptTerms});
  Future<void> end({String? studioId, String? collaboratorId});
  Future<void> setDefaultFee(String collaboratorId, int? fee);
  Future<OfferStatus> respondOffer(String bookingId, {required bool accept});
  Future<void> reportPaid(String bookingId, String collaboratorId, {required DateTime paidOn, required CollabPayMethod method});
  Future<void> confirmPay(String bookingId, {required bool received});
  Future<String> openChat({String? studioId, String? collaboratorId});
}
String collabCsv(List<CollabJob> jobs, AppLocalizations l);   // header + rows, RFC 4180 quoting
// providers (lib/data/recruit/recruit_providers.dart, lib/data/collab/collab_providers.dart)
final recruitRepositoryProvider; final collabRepositoryProvider;
final myProviderFactsProvider;      // StreamProvider.autoDispose<ProviderFacts?>
final myRecruitCountersProvider;    // StreamProvider.autoDispose<RecruitCounters>
final studioOpenRecruitCountProvider; // FutureProvider.autoDispose.family<int, String>
```

Routes (`lib/app/router.dart`): `/recruit` (`RecruitListScreen`, query `studioId`), `/recruit/:postId` (`RecruitDetailScreen`), `/studio/recruit` (`StudioRecruitScreen`, query `post`), `/studio/recruit/new` and `/studio/recruit/:postId/edit` (`RecruitEditScreen`), `/collab` (`CollabScreen`, query `offer`). `AppIcons` gains `handshake` (`Symbols.handshake_rounded`), `campaign` (`Symbols.campaign_rounded`), `eventRepeat` (`Symbols.event_repeat_rounded`). `ChatKind` gains `collab`.

### l10n keys (`lib/l10n/app_vi.arb`, verbatim; placeholders are `String` unless noted)

| key | text |
|---|---|
| `recruitTab` / `recruitTitle` | "Tuyển thợ" |
| `recruitStudioPostsTooltip` | "Tin tuyển của studio" |
| `recruitFilterArea` / `recruitFilterSpecialty` | "Khu vực" / "Thể loại" |
| `recruitKindCollaborator` / `recruitKindMember` | "Cộng tác theo việc" / "Vào studio" |
| `recruitMatch` | "Hợp với bạn" |
| `recruitFeePerShoot` | "{amount}/buổi" |
| `recruitFeeNegotiable` | "Thoả thuận" |
| `recruitFrequencyOccasional` / `recruitFrequencyWeekly` / `recruitFrequencySeasonal` | "Vài buổi/tháng" / "Hằng tuần" / "Theo mùa" |
| `recruitFrequencyOccasionalLong` / `recruitFrequencyWeeklyLong` / `recruitFrequencySeasonalLong` | "Vài buổi mỗi tháng" / "Hằng tuần" / "Theo mùa (cưới, Tết…)" |
| `recruitCardFooter` | "{frequency} · {ago}" |
| `recruitOnlyProvidersNote` | "Chỉ thợ ảnh và studio thấy mục này." |
| `recruitEmpty` | "Chưa có tin tuyển nào hợp bộ lọc." |
| `recruitLoadMore` | "Xem thêm" |
| `recruitSpecialtiesLabel` / `recruitAreasLabel` / `recruitFrequencyLabel` | "Thể loại" / "Khu vực làm việc" / "Tần suất" |
| `recruitFeeLabel` | "Thù lao tham khảo · studio trả trực tiếp cho bạn, ngoài ứng dụng" |
| `recruitRequirements` | "Yêu cầu" |
| `recruitStats` | "{count} người đã ứng tuyển · còn {days} ngày" (`count`, `days` int) |
| `recruitViewStudio` | "Xem studio" |
| `recruitApply` | "Ứng tuyển" |
| `recruitVerifyToApply` | "Xác minh để ứng tuyển" |
| `recruitVerifyNote` | "Bạn cần xác minh danh tính trước khi ứng tuyển." |
| `recruitApplied` | "Đã ứng tuyển · chờ studio" |
| `recruitWithdraw` | "Rút ứng tuyển" |
| `recruitWithdrawConfirmTitle` | "Rút ứng tuyển?" |
| `recruitWithdrawConfirmBody` | "Mỗi tin chỉ ứng tuyển một lần, rút rồi không gửi lại được." |
| `recruitAlreadyMember` | "Bạn đang là thành viên của {studio}." |
| `recruitStudioViewerNote` | "Studio xem được tin nhưng không ứng tuyển." |
| `recruitClosedNote` | "Tin đã đóng hoặc hết hạn." |
| `recruitResultAccepted` / `recruitResultDeclined` | "Studio đã nhận bạn" / "Studio chưa nhận ứng tuyển này" |
| `recruitApplyTitle` | "Ứng tuyển" |
| `recruitMessageLabel` / `recruitMessageHint` | "Lời nhắn cho studio" / "Giới thiệu ngắn về kinh nghiệm và thiết bị của bạn" |
| `recruitSamplesLabel` / `recruitSamplesHint` | "Ảnh tiêu biểu" / "Chọn tối đa 3 bài từ portfolio" |
| `recruitSamplesCount` | "{n}/3" (`n` int) |
| `collabTermsTitle` | "Điều khoản cộng tác" |
| `collabTerm1` | "Hợp đồng dịch vụ theo từng buổi chụp: bạn tự quyết cách làm, không có giờ làm cố định, không độc quyền." |
| `collabTerm2` | "Thù lao do hai bên thoả thuận từng việc. Studio trả trực tiếp cho bạn ngoài ứng dụng; ứng dụng không bảo lãnh khoản này." |
| `collabTerm3` | "Bạn không chào trực tiếp khách mà studio giao cho bạn trong 6 tháng." |
| `collabTermsAgree` | "Tôi đồng ý điều khoản cộng tác" |
| `recruitNoContactNote` | "Không ghi số điện thoại, Zalo hay link trong lời nhắn." |
| `recruitMemberNote` | "Được nhận thì bạn vào {studio} như thành viên (mỗi thợ ở một studio)." |
| `recruitSend` / `recruitSentToast` | "Gửi ứng tuyển" / "Đã gửi ứng tuyển" |
| `recruitNewTitle` / `recruitEditTitle` | "Đăng tin tuyển" / "Sửa tin tuyển" |
| `recruitOpenSlots` | "Còn {left}/3 tin mở" (`left` int) |
| `recruitKindLabel` | "Loại tin" |
| `recruitKindCollaboratorHint` | "Thợ làm từng buổi, không vào studio" |
| `recruitKindMemberLabel` / `recruitKindMemberHint` | "Thành viên studio" / "Thợ vào studio của bạn" |
| `recruitTitleLabel` | "Tiêu đề" |
| `recruitSpecialtiesPick` / `recruitAreasPick` | "Thể loại (tối đa 4)" / "Khu vực (tối đa 5)" |
| `recruitFeeKindPerShoot` / `recruitFeeKindNegotiable` | "Theo buổi" / "Thoả thuận" |
| `recruitFeeAmountHint` | "Số tiền mỗi buổi" |
| `recruitRequirementsHint` | "Thiết bị, kinh nghiệm, cách làm việc" |
| `recruitFormNote` | "Không ghi số điện thoại, Zalo hay link. Tin hiện 30 ngày, chỉ thợ ảnh và studio thấy." |
| `recruitPublish` / `recruitSave` / `recruitPostedToast` | "Đăng tin" / "Lưu thay đổi" / "Đã đăng tin" |
| `recruitTitleError` | "Tiêu đề 8–80 ký tự" |
| `recruitSpecialtiesError` / `recruitAreasError` | "Chọn 1–4 thể loại" / "Chọn 1–5 khu vực" |
| `recruitFeeError` | "Nhập số tiền mỗi buổi" |
| `recruitContactError` | "Bỏ số điện thoại, Zalo hoặc link ra khỏi nội dung" |
| `recruitStudioTitle` | "Tin tuyển của studio" |
| `recruitStudioMeta` | "{open}/3 tin mở · còn {left} lượt đăng/đóng hôm nay" (`open`, `left` int) |
| `recruitStatusOpen` / `recruitStatusClosed` / `recruitStatusExpired` | "Đang mở" / "Đã đóng" / "Hết hạn" |
| `recruitPostMeta` | "{count} ứng viên · còn {days} ngày" (int) |
| `recruitEdit` / `recruitRenew` / `recruitClose` | "Sửa" / "Gia hạn 30 ngày" / "Đóng tin" |
| `recruitCloseConfirmTitle` / `recruitCloseConfirmBody` | "Đóng tin này?" / "Ứng viên đang chờ được báo là chưa được nhận." |
| `recruitApplicantsHeader` | "Ứng viên · {title}" |
| `recruitApplicantsPending` | "{n} chờ trả lời" (int) |
| `recruitAccept` / `recruitDecline` | "Nhận" / "Từ chối" |
| `recruitNewPost` / `recruitFull` | "Đăng tin mới" / "Đã đủ 3 tin mở" |
| `recruitVerifyToPost` | "Xác minh để đăng tin" |
| `recruitBlocked` | "Bạn tạm không đăng tin và mời cộng tác viên tới {date} vì chưa trả thù lao cho cộng tác viên." |
| `recruitNoApplicants` | "Chưa có ai ứng tuyển." |
| `recruitNoPosts` | "Chưa có tin tuyển. Đăng tin để thợ ảnh khu vực của bạn thấy." |
| `recruitAcceptConflict` | "{name} đang ở studio khác hoặc đang cộng tác với studio bạn." |
| `recruitAcceptCooldown` | "{name} mới rời studio, chưa vào được studio mới." |
| `recruitAcceptStudioFull` / `recruitAcceptCollabFull` | "Studio đã đủ thành viên." / "Đã đủ số cộng tác viên." |
| `collabTitle` | "Cộng tác" |
| `collabStudioMeta` | "{active}/{max} cộng tác viên · còn {left} thao tác hôm nay" (int) |
| `collabRowMeta` / `collabRowMetaNoFee` | "{jobs} việc đang giao · gợi ý {fee}/buổi" / "{jobs} việc đang giao" |
| `collabMenuMessage` / `collabMenuFee` / `collabMenuEnd` | "Nhắn tin" / "Sửa thù lao gợi ý" / "Kết thúc cộng tác" |
| `collabEndConfirmTitle` / `collabEndConfirmBody` | "Kết thúc cộng tác với {name}?" / "Mời lại được sau 3 ngày." |
| `collabEndBusy` | "Còn {n} việc được giao chưa xong." (int) |
| `collabPayDueHeader` | "Thù lao cần trả" |
| `collabPayDue` / `collabPayDisputed` / `collabPayReported` / `collabPayReceived` | "Cần trả" / "Chưa nhận" / "Đã báo trả" / "Đã nhận" |
| `collabMarkPaid` | "Đã trả" |
| `collabPendingHeader` | "Đang chờ" |
| `collabInviteSent` | "Lời mời đã gửi · hết hạn sau {days} ngày" (int) |
| `collabCancelInvite` | "Huỷ" |
| `collabTaxNote` | "Khoản từ 5.000.000đ/lần có thể phải khấu trừ thuế TNCN 10%; hãy hỏi kế toán." |
| `collabExportCsv` | "Sao chép bảng kê tháng {month} (CSV)" (int) |
| `collabExportDone` | "Đã sao chép bảng kê tháng {month}. Dán vào bảng tính để xem." (int) |
| `collabInvite` | "Mời cộng tác viên" |
| `collabPaidSheetTitle` / `collabPaidDate` / `collabPaidMethod` | "Đã trả thù lao" / "Ngày trả" / "Cách trả" |
| `collabMethodBank` / `collabMethodCash` / `collabMethodOther` | "Chuyển khoản" / "Tiền mặt" / "Khác" |
| `collabPaidConfirm` | "Xác nhận đã trả" |
| `collabFeeSheetTitle` / `collabFeeHint` / `collabFeeSave` | "Thù lao gợi ý" / "Gợi ý sẵn khi giao việc cho {name}" / "Lưu" |
| `collabInviteSearch` | "Tìm thợ theo tên" |
| `collabInviteRowMember` / `collabInviteRowActive` / `collabInviteRowUnverified` | "Thành viên của studio bạn" / "Đang cộng tác" / "Chưa xác minh" |
| `collabInviteRowCooldown` | "Mời lại được từ {date}" |
| `collabInviteFooter` | "Lời mời hết hạn sau 7 ngày · tối đa 5 lời mời chờ" |
| `collabInviteAction` | "Mời" |
| `collabOffersHeader` / `collabOfferLeft` | "Việc chờ nhận" / "Còn {time}" |
| `collabStudiosHeader` / `collabStudiosCount` | "Studio cộng tác" / "{n} / tối đa 5" (int) |
| `collabStudioRowMeta` | "Từ {month} · {jobs} việc đang giao" (`jobs` int) |
| `collabInvitesHeader` / `collabInviteRowMeta` | "Lời mời" / "Mời cộng tác · hết hạn sau {days} ngày" (int) |
| `collabAcceptInvite` / `collabDeclineInvite` | "Xem & nhận" / "Từ chối" |
| `collabAcceptSheetTitle` / `collabAcceptSheetConfirm` | "Cộng tác với {studio}" / "Nhận lời cộng tác" |
| `collabPayHeader` | "Thù lao" |
| `collabPayReportedMeta` | "Studio báo đã trả {date} ({method})" |
| `collabConfirmReceived` / `collabReportNotReceived` | "Đã nhận" / "Chưa nhận" |
| `collabNotReceivedConfirmTitle` / `collabNotReceivedConfirmBody` | "Báo chưa nhận thù lao?" / "Studio và bộ phận hỗ trợ được báo. Ứng dụng không bảo lãnh khoản này." |
| `collabEmpty` | "Chưa có studio cộng tác. Xem tin ở Công việc → Tuyển thợ." |
| `collabOfferTitle` | "Nhận việc cộng tác" |
| `collabOfferStudioNote` | "Studio chịu trách nhiệm với khách và lo bàn giao ảnh" |
| `collabOfferFeeNote` | "Thù lao · studio trả trực tiếp cho bạn sau buổi chụp" |
| `collabOfferDeadline` / `collabOfferDeadlineNote` | "Trả lời trước {time} (còn {left})" / "Không trả lời coi như từ chối" |
| `collabOfferLockNote` | "Nhận việc thì khung giờ này bị khoá trên lịch của bạn và bạn vào hội thoại với khách." |
| `collabOfferAccept` / `collabOfferDecline` | "Nhận việc" / "Từ chối" |
| `collabOfferAcceptedToast` / `collabOfferDeclinedToast` / `collabOfferExpired` | "Đã nhận việc" / "Đã từ chối, studio được báo" / "Việc này đã hết hạn trả lời" |
| `assignGroupMembers` / `assignGroupCollaborators` | "Thành viên" / "Cộng tác viên" |
| `assignFeeLabel` / `assignFeeRequired` | "Thù lao" / "Nhập thù lao cho cộng tác viên" |
| `assignCollabNote` | "{name} có 6 giờ để nhận việc; khách chỉ thấy thợ khi {name} đã nhận." |
| `assignSendTo` | "Gửi việc cho {name}" |
| `assignOfferPending` | "Chờ {name} nhận · còn {left}" |
| `assignOfferDeclined` | "{name} đã từ chối. Giao người khác trước {deadline}." |
| `assigneeCollabLabel` | "Cộng tác với {studio}" |
| `workCollabLabel` | "Cộng tác · {studio}" |
| `settingsCollab` | "Cộng tác" |
| `settingsCollabProviderMeta` | "{studios} studio · {offers} việc chờ nhận" (int) |
| `settingsCollabStudioMeta` | "{n} cộng tác viên" (int) |
| `settingsRecruit` / `settingsRecruitMeta` | "Tin tuyển" / "{n}/3 tin mở" (int) |
| `profileRecruiting` | "Đang tuyển · {n} tin" (int) |
| `chatKindCollab` | "Cộng tác" |
| `recruitErrorGeneric` | "Chưa thực hiện được. Thử lại sau." |
| `recruitErrorRateLimited` | "Bạn đã dùng hết lượt hôm nay. Thử lại ngày mai." |
| `recruitErrorApplyLimit` | "Bạn đang có 10 ứng tuyển chờ trả lời. Chờ studio trả lời hoặc rút bớt." |
| `recruitErrorPostLimit` | "Studio đã có 3 tin mở." |
| `recruitErrorClosed` | "Tin đã đóng hoặc hết hạn." |
| `recruitErrorDuplicate` | "Bạn đã ứng tuyển tin này." |
| `collabErrorFull` | "Đã đủ số cộng tác cho phép." |
| `collabErrorCooldown` | "Chưa mời lại được, chờ đủ 3 ngày." |
| `collabErrorBusy` | "Còn việc được giao chưa xong." |
| `collabErrorConflict` | "Thợ này đang là thành viên của studio bạn." |
| `collabErrorDayTaken` | "Bạn đã có lịch trong ngày này." |

## Review Focus

1. **R3 visibility.** A signed-out user, a customer, and a user in customer mode who still has an old `photographers/{uid}` doc can never read `recruitPosts` (get or list); the S03.01 "Đang tuyển" line never renders or queries for them; posts never appear in Home, Find, Explore or a share link. Pinned: Task 5 rules tests "customer cannot read recruit posts", "customer-mode account with a photographers doc cannot read", "signed-out cannot list", "unverified photographer can read"; Task 7 "customer viewer of a studio profile sees no Đang tuyển line and the repository is not called".
2. **The studio's cost stays private.** The customer can read the booking but never the agreed fee or the pay record. Pinned: Task 4 "assigning to a collaborator writes no fee on the booking"; Task 5 rules "customer cannot read collab_jobs", "another photographer cannot read collab_jobs".
3. **Contact R8.** A collaborator with a pending, declined, expired or replaced offer cannot read the customer's contact and the customer cannot open the collaborator's channels; it opens only after acceptance (booking already paid) and closes 7 days after completed/cancelled. Pinned: Task 4 `collaboratorContactOpen` table and the `getContactLink` case; Task 5 rules "pending collaborator cannot read customer contact", "accepted collaborator can", "replaced collaborator cannot".
4. **Limits and counters under every path.** 3 open posts, 10 open applications, 5/50 collaborators, 5 collaborations per collaborator, 5 pending invites and the daily quotas (VN midnight) hold for concurrent calls and never drift: every exit (decline, withdraw, close, expire, cancel, end, sweep) decrements exactly once. Pinned: Task 2 "every exit path from applied decrements openApplicationCount once" and "closing a post with 3 applicants…", Task 3 "the sixth active collaboration is refused" and "expiring an invite frees a pending slot", Task 4 sweeps idempotency.
5. **Offer timing vs the S26 deadline.** An offer never outlives `assignDeadline` (or `startAt` when assigned late), the calendar is blocked only on acceptance, a declined or expired offer clears the assignee so S26's overdue path (T6/T8, refund 100%) still fires, and a second `assignBooking` replaces a pending offer. Pinned: Task 4 `offerExpiry` table, "decline clears assigneeId and notifies the studio", "expired offer then S26 sweep marks assignOverdue", "re-assign marks the old job replaced".

## Chi phí Google

Unit prices from `2026-10-07-google-cloud-costs.md`: Firestore at the nam5 upper bound $0.06/100K reads, $0.18/100K writes (Singapore price **chưa xác nhận**); Functions Tier 2, 2M calls and 180K vCPU-s free per month; FCM free; scheduler $0.10/job/31 days after 3 free. Assumptions: (b) 1,000 MAU, 100 providers, ~10 studios; (c) 10,000 MAU, 1,000 providers, ~100 studios; 1.5 new posts per studio per month; 8 applications per post; collaborator offers on ~9% of bookings (30% studio bookings × 30% to collaborators).

**Reads/writes per user action**

| Action | Reads | Writes | Notes |
|---|---|---|---|
| Open S27.01 (tab or `/recruit`) | 20 + 1 (own photographer doc) | 0 | `get`, page of 20, cursor; "Xem thêm" +20. One composite index for every filter (Decision 7). |
| Open S27.02 | 4 (post, studio photographer + user, own application) | 0 | `get`; own application via a 1-doc listener (status changes while open). |
| Apply (S27.03) | ~8 (post, application, counters ×2, facts ×2, member state, posts owned) | 4 + grouped notification (~3 r, 2 w) | callable |
| Studio opens S27.05 | ~3 posts + ≤ 30 applicants + ≤ 30 summaries | 0 | posts listener limit 10; applicants `get` per selected post |
| Accept/decline applicant | ~8 | 4–6 + notification | callable |
| S27.06 (studio or photographer) | ≤ 60 collaborations + ≤ 50 jobs + 1 counters | 0 | listeners with limits: the other side changes pay status |
| Offer accept / decline (S27.07) | ~8 (booking, job, collaboration, availability, counters) | 5 + notifications | callable |
| Đã trả / Đã nhận | 3 | 2 + notification | callable |
| S03.01 studio profile (provider viewer) | 1 | 0 | `count()` aggregation, ≤ 3 matches |
| New post fan-out (trigger) | ≤ 200 + 4 per recipient | 3 per recipient | daily cap 3 per provider |

**New callables and triggers** — 16 new callables + `assignBooking` extended, 1 new trigger (`onRecruitPostCreated`), 2 extended triggers (`onPhotographerWrite`, `onBookingWrite`: a few extra reads, writes only on change). Calls/month: (b) ≈ 15 posts + 120 applications + 120 responses + 30 invites + 27 offers + 54 pay marks + chat opens ≈ 400 callable calls + ~375 extra `onNotificationWrite` runs; (c) ≈ 4,000 callable calls + ~22,500 notification-trigger runs. 256 MiB, 60 s timeout (defaults). All inside the free 2M calls and 180K vCPU-s (c: ≈ 27K calls × 0.2 vCPU-s ≈ 5,400 vCPU-s).

**Scheduled jobs** — none new. The S26 15-minute job (2,880 runs/month, 30 days as in every other plan) runs 6 extra queries per run (posts, applications, invites, offers, pay due, pay overdue): ≥ 6 reads per run even when empty ≈ 18K reads/month at any scale, plus the documents it processes.

**Storage** — no new path (applications reference existing portfolio posts; the CSV stays on the device). **Paid APIs** — none (no Maps, SMS, Cloud Tasks, Secret Manager).

**Monthly totals**

| | (b) 1,000 MAU | (c) 10,000 MAU |
|---|---|---|
| Fan-out reads/writes | ~1.9K r / 1.1K w | ~113K r / 68K w |
| Browsing S27.01/02 (4 + 3 opens per provider) | ~9.6K r | ~96K r |
| Apply + respond | ~2.8K r / 1.5K w | ~28K r / 15K w |
| Studio S27.05, S27.06, S03.01 line | ~9K r | ~98K r |
| Collab jobs and pay | ~1K r / 0.7K w | ~9K r / 6.5K w |
| Sweeps (piggyback) | ~18K r | ~19K r |
| **Firestore** | ~42K r, 3.3K w ≈ **$0.03** | ~363K r, 90K w ≈ $0.22 + $0.16 = **$0.38** |
| Functions (rule below) | $0 (free tier) | ≈ $0.2 (Tier 2: ~4K callables + ~22.5K trigger runs) |
| **Added per month** | **≈ $0.03** | **≈ $0.6** |

**Functions (one rule for every plan, cost spec §12):** at (b) new invocations and CPU fit the free tier (2M invocations, 180,000 vCPU-s, 360,000 GiB-s per month) → $0; at (c) the app already uses the free tier up (§12 (c): 2.5M invocations, ~500K vCPU-s), so this plan's Functions work is charged at Tier 2: $0.40/M invocations, $0.0000336/vCPU-s, $0.0000035/GiB-s.

Below the $5 threshold at (c); no mitigation needed. Cost guards built in: list pages of 20 with `get`, listeners only on small bounded sets, a 200-recipient fan-out cap and a 3-per-day notification cap, no new schedule.

---

## File Structure

| File | Responsibility |
|---|---|
| `docs/design/ui-mock.html`, `docs/superpowers/specs/2026-10-01-remaining-screens.md` §2, `app_flutter/lib/core/screen_codes.dart`, `CLAUDE.md` | Task 1: frames, code table, constants |
| `packages/domain/src/contact_filter.ts` (consumed from #139; created here only if #139 has not merged), `recruit_areas.ts`, `recruit.ts`, `recruit_ports.ts`, `recruit_use_cases.ts`, `memory_recruit_store.ts`, `recruit_notify.ts`; `errors.ts`, `index.ts` (modify; no notification module: #138's) | Task 2 |
| `packages/domain/src/studio_collaboration.ts`, `collab_use_cases.ts`; `studio_membership.ts` (S26, extract checker), `chat.ts` (kind `collab`), `open_collab_chat.ts` | Task 3 |
| `packages/domain/src/collab_jobs.ts`, `recruit_sweeps.ts`; S26 assignment module, `get_contact_link.ts` (modify) | Task 4 |
| `app_flutter/firebase/functions/src/infra/recruit_firestore.ts`, `live_recruit.ts`, `callables/recruit.ts`, `callables/collab.ts`, `triggers/recruit_post_created.ts`; `index.ts`, `callables/errors.ts`, `triggers/photographer_write.ts`, `triggers/booking_write.ts`, S26 job handler, `seed/fixtures.ts`, `seed/README.md`; `firestore.rules`, `firestore.indexes.json`, `rules-test/rules.test.mjs` | Task 5 |
| `app_flutter/lib/data/recruit/*`, `lib/data/collab/*`, `lib/data/chat/chat.dart`, `lib/core/theme/app_icons.dart` (icons #138's visuals use), `test/support/recruit_world.dart` | Task 6 |
| `app_flutter/lib/features/recruit/recruit_list_view.dart`, `recruit_list_screen.dart`, `recruit_list_controller.dart`, `recruit_card.dart`, `recruit_detail_screen.dart`, `recruit_apply_sheet.dart`, `collab_terms_card.dart`; `features/work/work_screen.dart`, `features/photographer_profile/widgets/profile_header.dart`, `lib/app/router.dart` | Task 7 |
| `app_flutter/lib/features/recruit/recruit_edit_screen.dart`, `recruit_edit_controller.dart`, `studio_recruit_screen.dart`, `studio_recruit_controller.dart` | Task 8 |
| `app_flutter/lib/features/collab/collab_screen.dart`, `collab_studio_view.dart`, `collab_member_view.dart`, `collab_offer_sheet.dart`, `collab_paid_sheet.dart`, `collab_fee_sheet.dart`, `collab_controller.dart`; S26 assign and invite sheets, S05.02 block, `work_screen.dart`, `settings_screen.dart`, chat list/screen | Task 9 |
| `docs/superpowers/specs/2026-10-07-studio-recruiting-design.md`, `data-model/domain-model.md`, `data-model/relational-schema.md`, `specs/screens/recruit.md` (new), `components/shared-components.md`, `docs/superpowers/handover/ledger-s27-studio-recruiting.md`, spec §2 status | Task 10 |

---

### Task 1: Mock frames S27.01–S27.07, screen-code table, constants

**Files:**
- Modify: `docs/design/ui-mock.html` (new section `<h2 id="S27">` right after the S26 section, before `<h2 id="S21">`; variant frames; caption edits of `S06.01`, `S09.02`, `S03.01-studio`; rows in the in-page code table at the end of the page), `docs/superpowers/specs/2026-10-01-remaining-screens.md` (§2 rows + the sentence after the table), `app_flutter/lib/core/screen_codes.dart`, `CLAUDE.md` (screen-code sentence)
- Test: `app_flutter/test/core/screen_codes_test.dart` (existing; must stay green)

**Interfaces:**
- Produces: frames `#S27.01`–`#S27.07`, `#S27.02-unverified`, `#S27.06-me`, `#S26.02-collab`, `#S26.04-collab`, `#S05.02-studio-collab`; `ScreenCodes.recruitList … collabOffer` (Decision 1) appended to `ScreenCodes.all`.

- [ ] **Step 1: Read the frame conventions.** Copy the shape of the S26 frames (`.step` > `.phone[data-code]` > `.scr` with `.sb`, `.body`, `.bar`, `.foot`; sheets use `.dim` + `.sheet` + `.grab`; caption `.cap` with `<span class="n new">Mới</span>`, code, `<b>` headline and `<span>` body). Use only existing classes (`card`, `irow`, `irow2`, `jcard`, `tag`, `fit`, `chips/chip`, `seg`, `optc/opt`, `field`, `chk`, `lockn`, `warnc`, `badge b-ok|b-warn|b-pen`, `btn pri|out|txt xs|sm`, `meta`, `sec`, `grid3 ph pN`, `av m`, `vfs` seal, `tm` tomato) and Material Symbols `<span class="ms">`. Write the section intro `<p>` and a `note2` "Quy tắc đã chốt" list with R1–R8 in one line each (copy the wording of spec §2).
- [ ] **Step 2: Add the frames with this exact copy** (Vietnamese verbatim; names and numbers are sample data):
  - `S27.01` — bar `<small>Công việc</small>Tuyển thợ`; seg "Hôm nay" · "Việc đang tuyển · 6" · "Báo giá của tôi" · **"Tuyển thợ"** (on); chips "Khu vực" (ms `expand_more`), "Thể loại", "Cộng tác theo việc", "Vào studio"; three `jcard`s: (1) tag "Cộng tác theo việc" + fit "Hợp với bạn"; b "Thợ phụ chụp cưới mùa cưới"; meta "Studio Mây [seal] · Quận 3, Quận 7 · Cưới, Gia đình"; row b "800.000₫/buổi" + meta x "Theo mùa · 4 ngày trước". (2) tag "Vào studio"; "Tuyển thành viên chụp kỷ yếu"; "Studio Nắng · Quận 1 · Kỷ yếu"; "Thoả thuận" + "Hằng tuần · hôm qua". (3) tag "Cộng tác theo việc"; "Chụp sự kiện công ty cuối năm"; "Studio Gió · Thủ Đức · Sự kiện"; "1.200.000₫/buổi" + "Vài buổi/tháng · 1 tuần trước"; then `lockn` (ms `lock`) "Chỉ thợ ảnh và studio thấy mục này."; tab bar with Công việc on. Caption: headline "Chỉ người làm nghề thấy" — body: tab mới cuối S06.01; ai thấy (R3); thợ chưa xác minh vẫn xem; lọc khu vực/thể loại/loại; sắp "Hợp với bạn" (khớp khu vực và thể loại với hồ sơ) rồi theo ngày đăng; 20 tin mỗi lần, "Xem thêm"; studio có thêm biểu tượng `campaign` "Tin tuyển của studio" ở thanh trên → S27.05; khách không có tab này.
  - `S27.02` — bar back; row tag "Cộng tác theo việc" + fit "Hợp với bạn"; display title "Thợ phụ chụp cưới mùa cưới"; studio row av + "Studio Mây" + seal, meta "[tomato]96% · 128 buổi chụp", `btn out xs` "Xem studio"; `irow`s: `photo_camera` "Cưới, Gia đình" small "Thể loại"; `location_on` "Quận 3, Quận 7" small "Khu vực làm việc"; `event_repeat` "Theo mùa (cưới, Tết…)" small "Tần suất"; `credit_card` "800.000₫/buổi" small "Thù lao tham khảo · studio trả trực tiếp cho bạn, ngoài ứng dụng"; `sec` "Yêu cầu"; meta "Có máy full-frame và ống 70-200. Đã chụp ít nhất 10 đám cưới. Chủ động bắt khoảnh khắc, không cần chỉ đạo."; meta x "12 người đã ứng tuyển · còn 26 ngày"; foot `btn pri` "Ứng tuyển". Caption lists the states: đã ứng tuyển → nút viền tắt "Đã ứng tuyển · chờ studio" + chữ "Rút ứng tuyển" (sheet xác nhận); studio đã nhận/chưa nhận → dòng kết quả; thành viên của chính studio → "Bạn đang là thành viên của Studio Mây." và không có nút; studio xem tin → "Studio xem được tin nhưng không ứng tuyển."; tin đóng/hết hạn → "Tin đã đóng hoặc hết hạn."; không có nút chia sẻ (R3).
  - `S27.02-unverified` — same top (title, studio row, two `irow`s), then `lockn` (ms `lock`) "Bạn cần xác minh danh tính trước khi ứng tuyển."; foot `btn pri` "Xác minh để ứng tuyển" (→ S21.02).
  - `S27.03` — S27.02 dimmed; sheet h3 "Ứng tuyển" + close; meta "Thợ phụ chụp cưới mùa cưới · Studio Mây"; `field` small "Lời nhắn cho studio" with meta "Giới thiệu ngắn về kinh nghiệm và thiết bị của bạn" and counter "0/400"; label "Ảnh tiêu biểu" + meta "Chọn tối đa 3 bài từ portfolio" + "2/3"; `grid3` (two selected with accent ring); card "Điều khoản cộng tác" with the three bullets `collabTerm1–3` verbatim (l10n table); `chk` (on) "Tôi đồng ý điều khoản cộng tác"; `lockn` info "Không ghi số điện thoại, Zalo hay link trong lời nhắn."; `btn pri` "Gửi ứng tuyển". Caption: tin `member` không có khối điều khoản, thay bằng dòng "Được nhận thì bạn vào Studio Mây như thành viên (mỗi thợ ở một studio)."; tối đa 10 ứng tuyển đang mở, 3 lần/ngày; mẫu điều khoản tối thiểu, cần luật sư duyệt trước khi chạy thật.
  - `S27.04` — bar back + "Đăng tin tuyển"; meta tn "Còn 2/3 tin mở"; label "Loại tin" + `optc` radios "Cộng tác theo việc" (small "Thợ làm từng buổi, không vào studio", on) / "Thành viên studio" (small "Thợ vào studio của bạn"); `field` "Tiêu đề" "Thợ phụ chụp cưới mùa cưới" "27/80"; "Thể loại (tối đa 4)" chips Cưới (on), Gia đình (on), Chân dung, Sự kiện; "Khu vực (tối đa 5)" chips Quận 3 (on), Quận 7 (on), Quận 1; "Tần suất" seg "Vài buổi mỗi tháng" / "Hằng tuần" / "Theo mùa (cưới, Tết…)" (on); "Thù lao tham khảo" seg "Theo buổi" (on) / "Thoả thuận" + field "800.000 ₫ / buổi"; `field` "Yêu cầu" with hint "Thiết bị, kinh nghiệm, cách làm việc" "0/600"; `lockn` info "Không ghi số điện thoại, Zalo hay link. Tin hiện 30 ngày, chỉ thợ ảnh và studio thấy."; foot `btn pri` "Đăng tin". Caption: chỉ studio đã xác minh; sửa: tiêu đề "Sửa tin tuyển", nút "Lưu thay đổi", loại tin khoá; lỗi dưới từng ô ("Tiêu đề 8–80 ký tự", "Chọn 1–4 thể loại", "Chọn 1–5 khu vực", "Nhập số tiền mỗi buổi", "Bỏ số điện thoại, Zalo hoặc link ra khỏi nội dung"); tối đa 3 tin mở, đăng/đóng 5 lần/ngày.
  - `S27.05` — bar back + "Tin tuyển của studio"; meta tn "2/3 tin mở · còn 3 lượt đăng/đóng hôm nay"; post card: row tag "Cộng tác theo việc" + badge b-ok "Đang mở"; b "Thợ phụ chụp cưới mùa cưới"; meta "12 ứng viên · còn 26 ngày"; row `btn txt xs` "Sửa" · "Gia hạn 30 ngày" · "Đóng tin"; second card tag "Vào studio" + badge b-ok "Đang mở", "Tuyển thành viên chụp kỷ yếu", "3 ứng viên · còn 9 ngày"; `sec` "Ứng viên · Thợ phụ chụp cưới mùa cưới" + "3 chờ trả lời"; applicant cards: av + "Lan Phương" + verified, meta "[tomato]95% · 42 buổi chụp", `grid3`, meta "Em đã chụp phụ 15 đám cưới, có 70-200 f2.8 và đèn rời…", row `btn out xs` "Từ chối" + `btn out xs` "Nhận"; second "Quốc Bảo" "[tomato]89% · 17 buổi chụp"; foot `btn pri` "Đăng tin mới". Caption: "Nhận" tin cộng tác → quan hệ cộng tác `active` ngay; tin thành viên → luật S26, lỗi báo đúng tên ("Lan Phương đang ở studio khác hoặc đang cộng tác với studio bạn.", "… mới rời studio, chưa vào được studio mới.", "Studio đã đủ thành viên."); "Đóng tin" → sheet xác nhận "Đóng tin này?" / "Ứng viên đang chờ được báo là chưa được nhận." (nút đỏ "Đóng tin"); gia hạn 1 lần; ứng tuyển không trả lời 7 ngày tự hết hạn; đủ 3 tin: nút chính tắt "Đã đủ 3 tin mở"; studio chưa xác minh: "Xác minh để đăng tin" (→ S21.02); bị khoá: `warnc` "Bạn tạm không đăng tin và mời cộng tác viên tới 12/11 vì chưa trả thù lao cho cộng tác viên."
  - `S27.06` (studio) — bar back + "Cộng tác"; meta tn "3/5 cộng tác viên · còn 8 thao tác hôm nay"; card of `irow2`: "Lan Phương" meta "[tomato]95% · 2 việc đang giao · gợi ý 800.000₫/buổi" + `more_horiz`; "Quốc Bảo" "1 việc đang giao"; "Thu Hà" "0 việc đang giao"; `sec` "Thù lao cần trả" "2"; card "Lan Phương · Cưới 4 giờ" meta "T7 12/10 · 800.000₫" badge b-warn "Cần trả" + `btn out xs` "Đã trả"; card "Quốc Bảo · Gia đình 2 giờ" "CN 6/10 · 500.000₫" badge b-bad "Chưa nhận"; `sec` "Đang chờ" "1"; `irow2` "Hoàng Yến" meta "Lời mời đã gửi · hết hạn sau 5 ngày" `btn txt xs` "Huỷ"; `lockn` info "Khoản từ 5.000.000đ/lần có thể phải khấu trừ thuế TNCN 10%; hãy hỏi kế toán."; `btn txt sm` "Sao chép bảng kê tháng 10 (CSV)"; foot `btn pri` "Mời cộng tác viên" (→ S26.02-collab). Caption: menu "…" = Nhắn tin / Sửa thù lao gợi ý / Kết thúc cộng tác (chữ đỏ → sheet xác nhận; còn việc chưa xong thì sheet nói "Còn 2 việc được giao chưa xong."); "Đã trả" mở sheet chọn ngày + cách trả (Chuyển khoản / Tiền mặt / Khác); quá 7 ngày chưa trả hoặc CTV báo "Chưa nhận" thì ghi cờ, 3 lần trong 90 ngày tạm khoá đăng tin và mời CTV; 5 CTV khi chưa xác minh doanh nghiệp, 50 khi đã xác minh; ứng dụng không chi hộ, không bảo lãnh.
  - `S27.06-me` (photographer) — bar back + "Cộng tác"; `sec` "Việc chờ nhận" "1"; card th + "Studio Mây · Cưới 4 giờ" meta "T7 12/10 · 15:30–19:30 · 800.000₫" badge b-warn "Còn 4 giờ"; `sec` "Studio cộng tác" "2 / tối đa 5"; `irow2` "Studio Mây" + seal, meta "Từ 09/2026 · 1 việc đang giao" + `more_horiz`; "Studio Gió" "Từ 10/2026 · 0 việc đang giao"; `sec` "Lời mời" "1"; card av "Studio Nắng" meta "Mời cộng tác · hết hạn sau 6 ngày" + `btn out xs` "Từ chối" + `btn out xs` "Xem & nhận"; `sec` "Thù lao"; card "Studio Mây · Cưới 4 giờ" meta "T7 5/10 · 800.000₫ · Studio báo đã trả 7/10 (Chuyển khoản)" + row `btn out xs` "Chưa nhận" + `btn out xs` "Đã nhận"; card "Studio Gió · Kỷ yếu" "T4 2/10 · 600.000₫" badge b-ok "Đã nhận". No primary button. Caption: "Xem & nhận" mở sheet "Cộng tác với Studio Nắng" có khối điều khoản + ô đồng ý + nút chính "Nhận lời cộng tác"; "Chưa nhận" → sheet xác nhận "Báo chưa nhận thù lao?"; không độc quyền, tối đa 5 studio; vẫn nhận booking cá nhân.
  - `S27.07` — S27.06-me dimmed; sheet h3 "Nhận việc cộng tác" + close; card th + "Cưới 4 giờ" meta "T7 12/10 · 15:30–19:30 · Quận 3"; `irow` `storefront` "Studio Mây" small "Studio chịu trách nhiệm với khách và lo bàn giao ảnh"; `irow` `credit_card` "800.000₫" small "Thù lao · studio trả trực tiếp cho bạn sau buổi chụp"; `irow` `schedule` "Trả lời trước 13:40 hôm nay (còn 3 giờ 52 phút)" small "Không trả lời coi như từ chối"; `lockn` info "Nhận việc thì khung giờ này bị khoá trên lịch của bạn và bạn vào hội thoại với khách."; row `btn out` "Từ chối" + `btn pri` "Nhận việc". Caption: không có liên hệ khách trong sheet; từ chối không tính vi phạm; hết 6 giờ coi như từ chối; studio được báo và giao người khác; trên S06.01 việc đã nhận có nhãn "Cộng tác · Studio Mây" (cùng chỗ nhãn "Giao bởi {Studio}" của S26).
  - `S26.02-collab` — copy `S26.02`; sheet title "Mời cộng tác viên"; rows: "Lan Phương" verified "[tomato]95% · Quận 3" `btn out xs` "Mời"; dim "Đức Anh" meta "Thành viên của studio bạn"; dim "Bảo Ngọc" meta "Mời lại được từ 14/10"; dim "Minh Trí" meta "Đang cộng tác"; dim "Văn Toàn" meta "Chưa xác minh"; footer meta x "Lời mời hết hạn sau 7 ngày · tối đa 5 lời mời chờ". Caption: thợ cá nhân hoặc NAG đã xác minh; thợ đang ở studio khác vẫn mời được (không độc quyền).
  - `S26.04-collab` — copy `S26.04`; inside `optc` two `sec`-style labels "Thành viên" (Minh Trí, Hồng Nhung) and "Cộng tác viên" (Lan Phương selected, meta "Rảnh · [tomato]95%"); under the selected collaborator a `field` small "Thù lao" "800.000 ₫"; `lockn` info "Lan Phương có 6 giờ để nhận việc; khách chỉ thấy thợ khi Lan Phương đã nhận."; `btn pri` "Gửi việc cho Lan Phương". Caption: thù lao bắt buộc khi chọn CTV, điền sẵn thù lao gợi ý; giao xong S05.02 phía studio hiện "Chờ Lan Phương nhận · còn 5 giờ 59 phút"; CTV từ chối → "Lan Phương đã từ chối. Giao người khác trước 15:30 T6 11/10."; khách không thấy thù lao.
  - `S05.02-studio-collab` — copy the "Thợ chụp cho bạn" block of `S05.02-studio` and add under the name `meta` "Cộng tác với Studio Mây". Caption: chỉ hiện khi CTV đã nhận việc; quyền xin đổi thợ như S26.05; studio vẫn chịu trách nhiệm.
  - Caption edits: `S06.01` add one sentence "Thêm đoạn cuối `SegmentedTabs`: "Tuyển thợ" (S27.01); việc cộng tác đã nhận có nhãn "Cộng tác · {Studio}"."; `S09.02` add "Thợ ảnh và studio có thêm dòng "Cộng tác" (biểu tượng `handshake`; phụ đề "{n} studio · {m} việc chờ nhận" với thợ, "{n} cộng tác viên" với studio) → S27.06; studio thêm dòng "Tin tuyển" (biểu tượng `campaign`, phụ đề "{n}/3 tin mở") → S27.05."; `S03.01-studio`: add a row `irow` (ms `campaign`) "Đang tuyển · 2 tin" under the members row, and the caption sentence "Dòng "Đang tuyển · {n} tin" chỉ hiện với thợ ảnh và studio, chạm mở S27.01 lọc theo studio này."
  - In-page code table: a group row "S27 · Studio tuyển thợ" and seven rows (S27.01 "Tin tuyển: danh sách, lọc (tab Tuyển thợ trong Công việc)" … S27.07 "Nhận việc cộng tác (sheet)", Mock "Có").
- [ ] **Step 3: Spec §2.** After the S26 block add `| **S27** | **Studio tuyển thợ** | | | | | |` and seven rows in the existing column format: `| S27.01 | Tin tuyển: danh sách, lọc khu vực / thể loại / loại (tab "Tuyển thợ" trong S06.01) | `/recruit` | thợ ảnh · studio | spec 10-07 tuyển thợ | ⬜ có mock, có plan | — |`, `S27.02 | Chi tiết tin tuyển | `/recruit/:postId``, `S27.03 | Ứng tuyển (sheet) | — (sheet) | thợ ảnh`, `S27.04 | Đăng / sửa tin (studio) | `/studio/recruit/new` | studio`, `S27.05 | Tin của studio và ứng viên | `/studio/recruit` | studio`, `S27.06 | Cộng tác (studio và thợ) | `/collab` | thợ ảnh · studio`, `S27.07 | Nhận việc cộng tác (sheet) | — (sheet) | thợ ảnh`. Below the S26 sentence add: "Use case S27 (**Studio tuyển thợ**) đặc tả ở [`2026-10-07-studio-recruiting-design.md`](2026-10-07-studio-recruiting-design.md)."
- [ ] **Step 4: Constants.** In `screen_codes.dart` add the block `// S27 Studio tuyển thợ.` with the seven constants of Decision 1 and append them to `all` in order.
- [ ] **Step 5: CLAUDE.md.** In the "Screen codes" sentence change "26 use cases `S01`–`S26`" to "27 use cases `S01`–`S27`" and add after the S26 clause: "S27 studio recruiting: recruit posts visible only to providers, per-job collaborators and an off-app pay record (`docs/superpowers/specs/2026-10-07-studio-recruiting-design.md`);".
- [ ] **Step 6: Run** `flutter test --no-pub --timeout 60s test/core/screen_codes_test.dart` → green (it checks the spec table equals `ScreenCodes.all`). Open the mock in a browser if available (`open` is blocked in the sandbox: skip and say so in the ledger); check by grep that every new `id` is unique: `grep -o 'id="S27[^"]*"' docs/design/ui-mock.html | sort | uniq -d` prints nothing.
- [ ] **Step 7: Commit** `docs(mock): S27 studio recruiting frames, code table and screen codes [#151]`.

### Task 2: Domain — recruit posts, applications, contact filter, areas, fan-out

**Files:**
- Create: `packages/domain/src/recruit_areas.ts`, `recruit.ts`, `recruit_ports.ts`, `recruit_use_cases.ts`, `memory_recruit_store.ts`, `recruit_notify.ts`; `contact_filter.ts` + `test/contact_filter.test.ts` only if absent (Decision 11: copy the jobs plan's Decision 15 regexes and its test table verbatim)
- Modify: `packages/domain/src/errors.ts` (codes; `DomainError.field` if absent), `index.ts` (no notification copy: #138's)
- Test: `packages/domain/test/recruit_areas.test.ts`, `recruit.test.ts`, `recruit_use_cases.test.ts`, `recruit_notify.test.ts`, `test/support/recruit_world.ts`

**Interfaces:**
- Consumes: `ProviderOrderGate`, `NotifyDeps`/`notify`, `isId`, `vnDayKey` (S21), `findContactLeak(text: string): 'phone' | 'email' | 'link' | 'zalo' | null` + `DomainError.field` (#139's, Decision 11), #198's `BlockGate.isBlockedEitherWay(a: string, b: string): Promise<boolean>`, #138's ten hooks (Contract signatures), S26's `checkMemberActivation` (only its type here; Task 3 calls it).
- Produces: everything under "Domain" for `recruit_areas.ts`, `recruit.ts`, `recruit_ports.ts`, `recruit_use_cases.ts`, `recruit_notify.ts` in the Contract; all ten notification types with their content and copy (emitted by Tasks 2–4); error codes of Decision 10. `RecruitWorld` (test support): in-memory `RecruitStore`, people map, order gate map, owned posts, fake notify recorder, fixed clock.

- [ ] **Step 1: Contract check** of the files in "Contract with existing code" and "What this plan expects from S26"; write the real S26 names into the ledger draft.
- [ ] **Step 2: Failing tests:**
  - `recruit.test.ts` (contact, #139's `findContactLeak`; copy #139's `contact_filter.test.ts` table and add these recruit rows): "0912 345 678" → phone, "+84 912345678" → phone, "a@b.vn" → email, "www.abc.com" → link, "studio.vn" → link, "zalo.me/0912345678" → link, "Zalo" → zalo; `ignores prices, years, lens sizes and times` ("800.000₫/buổi", "2026", "70-200mm", "15:30–19:30", "f2.8") → null; `an application message with any leak is invalid_argument with field message.contact`; `applying to a studio that blocked the applicant (either way) is blocked`.
  - `recruit_areas.test.ts`: `RECRUIT_AREAS has the 12 builtInAreas ids in order`; `recruitCityOf folds accents and aliases` ("TP.HCM", "Hồ Chí Minh", "Sài Gòn" → hcm; "Hà Nội" → hn; "Đà Nẵng" → dn; "Paris" → null); `areas by centre and radius` (centre Quận 1, 5 km → hcm-q1, hcm-q3, hcm-binh-thanh…); `areas by city when no centre`; `recruitMatchKeysOf is empty for studios and for customers`.
  - `recruit.test.ts`: `validateRecruitPostInput` table (title 7 → invalid, 8 ok, 81 invalid; 0/5 specialties invalid, unknown id invalid, duplicate invalid; 0/6 areas invalid; per_shoot amount 999, 1.500, 100.001.000 invalid, 800.000 ok; negotiable ok; requirements 601 invalid; phone in title or requirements → `invalid_argument` with field `title.contact` / `requirements.contact`; "liên hệ zalo nhé" → `requirements.contact`); `recruitFilterKeys has every non-empty combination and no duplicates` (1 kind × 2 areas × 2 specialties → 17 keys incl. `k=collaborator|a=hcm-q3|s=wedding`); `takeDaily resets at VN midnight` (16:59:59Z and 17:00:00Z are different VN days) and `throws rate_limited when full`.
  - `recruit_use_cases.test.ts`:
    - create: `a verified studio creates an open post with expiresAt +30 d, counters 1 open and 1 action`; `an unverified studio gets not_accepting_orders`; `an individual photographer gets invalid_argument`; `the fourth open post gets limit_exceeded`; `the sixth create or close of the VN day gets rate_limited`; `a blocked studio gets recruit_blocked`; `the post carries the studio snapshot, matchKeys and filterKeys`.
    - update/renew/close: `update only by the owner (permission_denied) and only while open (deadline_passed)`; `kind cannot change (invalid_argument)`; `renew once adds 30 days, a second renew is conflict, an expired post cannot be renewed`; `close declines every applied application, decrements each applicant's openApplicationCount once and openPostCount once, and notifies each applicant` (Review Focus 4).
    - apply: `an unverified photographer gets not_accepting_orders`; `a studio cannot apply (invalid_argument)`; `a member of the posting studio gets membership_conflict`; `collaborator kind without acceptTerms is invalid_argument`; `sample posts must be the applicant's own (invalid_argument) and at most 3`; `a message with a phone number gets invalid_argument with field message.contact`; `a second application to the same post is conflict, also after withdraw`; `the eleventh open application gets limit_exceeded`; `the fourth apply of the VN day gets rate_limited`; `applying to a closed or expired post is deadline_passed`; `apply increments applicationCount and sends one grouped recruit_application_new to the studio`.
    - withdraw: `only applied can be withdrawn; counter decremented once; a repeat is deadline_passed`.
    - respond (decline only; both accept branches are Task 3): `decline sets declined, respondedAt, decrements counters, counts one studio action, notifies the applicant`; `respond after the application expired is deadline_passed`; `only the posting studio may respond (permission_denied)`.
    - `every exit path from applied decrements openApplicationCount exactly once` (decline, withdraw, close, expire in sequence over four applications; counter ends at 0, never negative).
  - `recruit_notify.test.ts`: `notifies matching providers except the studio`; `a provider gets at most 3 recruit_post_new per VN day` (4th post same day → capped); `the cap resets the next VN day`; `stops at 200 recipients`; `a replayed trigger sends nothing twice` (dedupe key `recruit_post_new:<postId>`).
  - `recruit_notify.test.ts` also: `each use case calls the matching #138 hook with the Contract fields` (copy pinned by #138).
- [ ] **Step 3:** `cd packages/domain && npm test` → the new tests fail.
- [ ] **Step 4: Implement.** Memory store: refuse a read after a write inside a transaction (copy the `memory_event_store.ts` guard). Use cases read everything first, then write. Sample (apply):
  ```ts
  export async function applyToRecruitPost(deps: RecruitDeps, uid: string, raw: unknown) {
    const input = parseApplyInput(raw);                    // ids, message ≤ 400, ≤ 3 samples, acceptTerms bool
    if (findContactLeak(input.message) !== null) throw new DomainError('invalid_argument', 'message.contact'); // 'zalo' included
    const me = await deps.people.provider(uid);
    if (!me || me.role !== 'photographer' || me.providerType === 'studio') throw new DomainError('invalid_argument');
    if (!(await deps.orders.acceptsOrders(uid))) throw new DomainError('not_accepting_orders');
    if (!(await deps.posts.ownedBy(uid, input.samplePostIds))) throw new DomainError('invalid_argument');
    const now = deps.clock.now();
    const result = await deps.store.runTransaction(async (tx) => {
      const post = await tx.getPost(input.postId);
      if (!post) throw new DomainError('not_found');
      if (post.status !== 'open' || post.expiresAt <= now) throw new DomainError('deadline_passed');
      if (post.kind === 'collaborator' && !input.acceptTerms) throw new DomainError('invalid_argument');
      if ((await tx.activeMembershipStudioOf(uid)) === post.studioId) throw new DomainError('membership_conflict');
      if (await tx.getApplication(post.id, uid)) throw new DomainError('conflict');
      const c = await tx.getCounters(uid);
      if (c.openApplicationCount >= MAX_OPEN_APPLICATIONS) throw new DomainError('limit_exceeded');
      const applyActions = takeDaily(c.applyActions, now, APPLY_DAILY);   // throws rate_limited
      // ---- writes ----
      tx.putApplication({ id: `${post.id}_${uid}`, postId: post.id, studioId: post.studioId, applicantId: uid, kind: post.kind,
        postTitle: post.title, applicant: { name: me.name, avatarUrl: me.avatarUrl }, status: 'applied', message: input.message,
        samplePostIds: input.samplePostIds, termsAcceptedAt: post.kind === 'collaborator' ? now : null,
        createdAt: now, expiresAt: addDays(now, APPLICATION_TTL_DAYS), respondedAt: null });
      tx.putPost({ ...post, applicationCount: post.applicationCount + 1, updatedAt: now });
      tx.putCounters(uid, { ...c, openApplicationCount: c.openApplicationCount + 1, applyActions });
      return post;
    });
    await notify(deps.notify, { userId: result.studioId, groupKey: `recruit:${result.id}:apps`, actor: { id: uid, name: me.name, avatarUrl: me.avatarUrl },
      content: { type: 'recruit_application_new', name: me.name, title: result.title, count: 1 },
      target: `/studio/recruit?post=${result.id}`, dedupeKey: `recruit_application_new:${result.id}_${uid}`, eventId: `${result.id}_${uid}` });
    return { applicationId: `${result.id}_${uid}` };
  }
  ```
  Notifications are sent after the transaction commits and never fail the use case (catch, report through `deps.notify.onPushError` pattern / logger in the adapter). In this task `respondRecruitApplication` implements `accept: false` fully; `accept: true` refuses with `not_eligible` (one line, no test) and Task 3 replaces that line with the collaborator and member branches and their tests. Export new names from `index.ts`.
- [ ] **Step 5:** `npm test && npm run lint` → green (including `purity.test.ts`).
- [ ] **Step 6: Commit** `feat(domain): S27 recruit posts, applications and match fan-out [#151]`.

### Task 3: Domain — collaborations, member-kind acceptance, collab chat

**Files:**
- Create: `packages/domain/src/studio_collaboration.ts`, `collab_use_cases.ts`, `open_collab_chat.ts`
- Modify: `packages/domain/src/recruit_use_cases.ts` (accept branches), `studio_membership.ts` (S26: extract/export `checkMemberActivation`, add the "active collaboration with this studio" input → `membership_conflict`), `chat.ts` (`CHAT_KINDS` gains `'collab'`), `memory_recruit_store.ts`, `index.ts`
- Test: `packages/domain/test/studio_collaboration.test.ts`, `collab_use_cases.test.ts`, `open_collab_chat.test.ts`, `recruit_use_cases.test.ts` (accept cases), S26's membership test file (one added case), `chat.test.ts` (one case)

**Interfaces:**
- Consumes: Task 2 store, counters, `takeDaily`, notification types; S26 `checkMemberActivation(state, now): ErrorCode | null`, `MemberActivationState`, `MemberActivation` (record mapping).
- Produces: `studio_collaboration.ts` and `collab_use_cases.ts` of the Contract; `activateCollaboration`; `openCollabChat(chatDeps & {recruit: RecruitStore}, callerId, raw): Promise<{chatId}>`; `collabChatId(studioId, uid)`.

- [ ] **Step 1: Failing tests:**
  - `studio_collaboration.test.ts`: `collaboratorLimit is 5 without business verification and 50 with it`.
  - `collab_use_cases.test.ts`:
    - invite: `a verified studio invites a verified individual: status invited, expiresAt +7 d, pendingInviteCount 1, one studio action, collab_invite sent`; `an artist can be invited`; `a studio cannot be invited (invalid_argument)`; `an unverified collaborator or studio gets not_accepting_orders`; `a member of this studio gets membership_conflict`; `a member of another studio can be invited` (R6); `the sixth pending invite gets collab_full`; `invited or active already → conflict`; `re-invite within 3 days of ended → cooldown; at exactly 3 days → ok`; `re-invite archives the old record to history and overwrites the main one`; `the eleventh studio action of the VN day gets rate_limited`; `a blocked studio gets recruit_blocked`; `defaultFee must be 1.000–100.000.000 and a multiple of 1.000`.
    - cancel: `cancel an invite: cancelled, pending slot freed, one action`.
    - respond: `accept without acceptTerms → invalid_argument`; `accept: active, activeAt, termsAcceptedAt, counters (studio activeCollabCount +1, pendingInviteCount −1, collaborator activeCollabCount +1), collab_invite_result accepted`; `accept when the studio already has 5 (or 50) active → collab_full`; `accept when the collaborator has 5 active → collab_full`; `accept after expiresAt → deadline_passed`; `decline: declined, pending slot freed, result declined`; `responding does not count as an action`.
    - end: `either side ends an active collaboration: ended, endedAt, endedBy, counters −1 on both sides`; `end with an open job → member_busy` (store `openJobCount` 1); `the sixth end of the day by a collaborator → rate_limited`.
    - `the sixth active collaboration of a collaborator is refused (collab_full) even when two studios accept in parallel` (run two transactions on the memory store; one fails).
  - `recruit_use_cases.test.ts` (accept): `accepting a collaborator application creates an active collaboration with initiatedBy application and applicationId, marks the application accepted, sends recruit_application_result collaborator`; `accepting a member application writes an active studio_members record through putMember, counts S26's counters, sends studio_join_approved and recruit_application_result member`; `member accept reports S26's errors unchanged` (`membership_conflict`, `cooldown`, `studio_full` from `checkMemberActivation`); `member accept when the applicant is an active collaborator of this studio → membership_conflict` (Decision 12); `accepting a collaborator application when already active with this studio → conflict`.
  - S26 membership test: `an active collaboration with the same studio blocks activation with membership_conflict`.
  - `open_collab_chat.test.ts`: `creates collab_{studio}_{uid} with the studio in customerId and the collaborator in photographerId`; `returns the existing chat`; `refused (not_eligible) without an active collaboration`; `an ended collaboration less than 30 days old returns the chat read-only`.
  - `chat.test.ts`: `a collab chat has no inquiry limit` (studio sends 4 messages before any reply).
- [ ] **Step 2:** `npm test` → fail.
- [ ] **Step 3: Implement.** `activateCollaboration` is the single place that turns a pair into `active` (used by `respondRecruitApplication` and `respondCollabInvite`): it re-reads both counters and the main collaboration doc, enforces `collaboratorLimit`, `MAX_COLLABS_PER_COLLABORATOR`, `membership_conflict` (active member of this studio), archives a terminal previous record, writes the new record and both counters. Member-kind accept (sample):
  ```ts
  const state = await tx.getMemberState(post.studioId, app.applicantId);   // S26 shape, includes activeCollabWithStudio
  const refusal = checkMemberActivation(state, now);
  if (refusal) throw new DomainError(refusal);
  // writes: S26 record + counters through tx.putMember, then the application and the recruit counters
  ```
  `endCollaboration` returns the chat id for the adapter to set `readOnlyAt` after commit (Decision 16).
- [ ] **Step 4:** `npm test && npm run lint` → green (S26 tests too).
- [ ] **Step 5: Commit** `feat(domain): S27 studio collaborations, member-kind acceptance and collab chat [#151]`.

### Task 4: Domain — offers on studio bookings, pay record, sweeps, poaching signal

**Files:**
- Create: `packages/domain/src/collab_jobs.ts`, `recruit_sweeps.ts`
- Modify: the S26 assignment module (`assignBooking`, "Trả việc", its ports and memory store), `get_contact_link.ts` (assignee branch), `index.ts`
- Test: `packages/domain/test/collab_jobs.test.ts`, `recruit_sweeps.test.ts`, S26's assignment test file (collaborator cases), `get_contact_link.test.ts` (collaborator cases), S26/#130 review test (one regression case)

**Interfaces:**
- Consumes: Task 2–3 store and types; S26 `AssignTx` (gains `getCollaboration`, `getCollabJob`, `putCollabJob`, `getRecruitCounters`), S26 assignment notifications (`booking_assigned`), `ProviderOrderGate`.
- Produces: `collab_jobs.ts` and `recruit_sweeps.ts` of the Contract; `assignBooking` accepting `{assigneeKind: 'collaborator', agreedFee}`; `respondCollabOffer`, `reportCollabPaid`, `confirmCollabPay`; `syncCollabJobOnBooking(job, booking)` (pure: booking cancelled → `cancelled` if pending/accepted, `closedAt`; completed/reviewed → `closedAt`); `poachingSignal`.

- [ ] **Step 1: Failing tests:**
  - `collab_jobs.test.ts`: `offerExpiry` table (`now + 6 h` before the deadline; capped at `assignDeadline`; after the deadline capped at `startAt`; null when < 15 min remain); `collaboratorContactOpen` table (member → true as S26; collaborator not accepted → false; accepted + `requested|accepted|upcoming|…` → true; completed 6 d 23 h ago → true, 7 d → false; cancelled 7 d → false); `addUnpaidFlag prunes flags older than 90 d and blocks for 30 d at the third`; `isRecruitBlocked`.
  - S26 assignment tests (collaborator):
    - `assigning to an active collaborator creates a pending collab_job with the fee and offerExpiresAt, sets assigneeId, assigneeKind collaborator, assigneeAccepted false, and sends collab_assignment_offer`; `assigning to a collaborator writes no fee on the booking` (Review Focus 2: no key containing `fee` or `pay` in the booking or its assignment entry); `no calendar block, no chat member, no booking_assigned to the customer at offer time`.
    - `refused: no active collaboration (not_found), fee missing or off-step (invalid_argument), collaborator not accepting orders (not_accepting_orders), studio blocked (recruit_blocked), less than 15 minutes left (deadline_passed), collaborator busy that day (day_taken)`.
    - `re-assign while an offer is pending marks the old job replaced and notifies nobody but the new assignee`.
    - `accept: offerStatus accepted, acceptedAt, booking assigneeAccepted true, calendar blocked, chat member added, booking_assigned to the customer, collab_assignment_result accepted to the studio`; `accept after offerExpiresAt → deadline_passed`; `accept by someone else → permission_denied`; `accept when the day was taken meanwhile → day_taken and the offer stays pending`.
    - `decline clears assigneeId and assigneeKind, keeps assignDeadline, notifies the studio with the deadline`; `a declined or expired offer does not count as a violation` (S26 counters unchanged).
    - `"Trả việc" by an accepted collaborator marks the job returned and creates no pay record`.
  - `get_contact_link.test.ts`: `the customer cannot open a pending collaborator's channels (contact_locked)`; `can after acceptance`; `a replaced collaborator is not the subject any more (permission_denied or contact_locked per S26's shape)`.
  - pay: `reportCollabPaid by the studio on a due job → paid_reported with paidOn and method, collab_pay_reported sent`; `paidOn in the future → invalid_argument`; `by the collaborator → permission_denied`; `on a none or received job → conflict`; `confirmCollabPay received → received`; `not received → disputed, collab_pay_disputed to the studio`; `a disputed job can be reported paid again` (back to `paid_reported`).
  - `recruit_sweeps.test.ts`: `expires open posts past expiresAt and cascades their applications to expired`; `expires applied applications after 7 d with recruit_application_result expired`; `expires invites after 7 d with collab_invite_result expired`; `expires pending offers: assignee cleared, collab_assignment_result expired`; `then S26's sweep marks assignOverdue for that booking when its deadline passed` (Review Focus 5); `sets due once milestone 1 is released, with collab_pay_due`; `flags a job still due 7 d after dueAt exactly once`; `flags a disputed job exactly once`; `the third flag in 90 d sets recruitBlockedUntil`; `running the sweep twice changes nothing the second time` (idempotent).
  - `poachingSignal`: `two personal bookings with the same customer within 183 d of an accepted job → the jobs`; `one booking → null`; `a job older than 183 d → null`.
  - review regression: `a studio booking finished by a collaborator produces the photographer review for the collaborator tagged with the studio` (S26 §6).
- [ ] **Step 2:** `npm test` → fail.
- [ ] **Step 3: Implement.** The offer acceptance is the delicate transaction (sample):
  ```ts
  return deps.bookings.runTransaction(async (tx) => {            // S26 AssignTx
    const b = await tx.getBooking(input.bookingId);
    const job = b && b.assigneeId === uid && b.assigneeKind === 'collaborator' ? await tx.getCollabJob(b.id, uid) : null;
    if (!b || !job) throw new DomainError(b ? 'permission_denied' : 'not_found');
    if (job.offerStatus !== 'pending' || job.offerExpiresAt <= now) throw new DomainError('deadline_passed');
    if (!input.accept) { /* writes: job declined; booking assignee cleared; assignment entry declinedAt */ return 'declined'; }
    const day = await tx.availability(uid, b.day);                // S26's reader
    if (day && day.state !== 'off' && day.bookingId !== b.id) throw new DomainError('day_taken');
    // ---- writes ----
    tx.putCollabJob({ ...job, offerStatus: 'accepted', acceptedAt: now, updatedAt: now });
    tx.putBooking({ ...b, assigneeAccepted: true, assignments: markAccepted(b.assignments, uid, now), version: b.version + 1, updatedAt: now });
    tx.blockCalendar(uid, b.day, b.id);                            // S26's helper, same as a member assignment
    tx.addChatMember(b.chatId, uid);                               // S26's helper
    return 'accepted';
  });
  ```
  Notifications after commit. `runRecruitSweeps` processes each due list in pages of 200, each item in its own transaction that re-reads the item and does nothing when it no longer qualifies (idempotent).
- [ ] **Step 4:** `npm test && npm run lint` → green.
- [ ] **Step 5: Commit** `feat(domain): S27 collaborator offers, off-app pay record and recruit sweeps [#151]`.

### Task 5: Functions, rules, indexes and seed

**Files:**
- Create: `app_flutter/firebase/functions/src/infra/recruit_firestore.ts` (`FirestoreRecruitStore`, people reader, owned-posts reader, milestone reader, `matchingProviders`), `src/infra/live_recruit.ts` (`liveRecruitDeps()`, which sets `blocks: liveBlockGate()` from #198's `src/infra/live_safety.ts` explicitly — unit test `liveRecruitDeps wires a BlockGate`), `src/callables/recruit.ts`, `src/callables/collab.ts`, `src/triggers/recruit_post_created.ts`
- Modify: `src/index.ts` (16 callables + 1 trigger; the S26 15-minute `bookingClock` gains the step `recruitSweeps` = `handleRecruitSweeps()` at the end of its step list, own try/catch, dependency in the optional `BookingClockExtras.recruit` — clock rule, restated in `2026-10-08-s04-reconciliation.md`), `src/callables/errors.ts` (codes of Decision 10), `src/triggers/photographer_write.ts` (`syncRecruitMatchKeys`), `src/triggers/booking_write.ts` (`syncCollabJob`, `flagPoaching`), the S26 Firestore assignment adapter (collab job + recruit counters inside the assign transaction), `src/infra/chat_firestore.ts` (map kind `collab`; `setReadOnly(chatId, at)`), `seed/fixtures.ts`, `seed/README.md`; `app_flutter/firebase/firestore.rules`, `firestore.indexes.json`, `rules-test/rules.test.mjs`
- Test: `functions/test/unit/recruit_callables.test.ts`, `collab_callables.test.ts`, `recruit_post_created.test.ts`, `recruit_firestore_mapping.test.ts`, `photographer_write.test.ts` (extend), `booking_write` test (extend or create `booking_write_collab.test.ts`), `errors.test.ts`, `seed_fixtures.test.ts`

**Interfaces:**
- Consumes: Tasks 2–4 domain.
- Produces: callables and triggers of the Contract; `export async function syncRecruitMatchKeys(input: PhotographerWriteInput, writer: { set(uid: string, keys: string[]): Promise<void> }): Promise<'written' | 'unchanged' | 'deleted'>` (reads `users/{uid}.role` once through an injected reader; writes only when the sorted list differs, so its own write cannot loop); `handleRecruitSweeps(deps = liveRecruitDeps())`; Firestore mapping `recruitPostFromDoc/ToDoc`, `applicationFromDoc/ToDoc`, `collaborationFromDoc/ToDoc`, `collabJobFromDoc/ToDoc`, `countersFromDoc/ToDoc` (Timestamps ↔ `Date`, missing fields → defaults).

- [ ] **Step 1: Failing tests:**
  - callables: for each callable, `unauthenticated → unauthenticated`, `domain refusal → the mapped HttpsError with details.code` (one representative code each), `happy path calls the domain with the caller uid`; `assignBooking passes assigneeKind and agreedFee through`.
  - `recruit_post_created.test.ts`: `calls notifyRecruitMatches once per created post`; `an expired event (older than MAX_EVENT_AGE_MS) does nothing`.
  - `photographer_write.test.ts`: `syncRecruitMatchKeys writes keys for an individual in TP.HCM with wedding`; `writes [] for a studio`; `writes nothing when the keys already match` (re-fire); `writes nothing for a deleted doc`; `a customer-mode role writes []`.
  - booking write: `a cancelled studio booking cancels its pending collab job`; `a completed booking sets closedAt`; `a second personal booking with a customer the collaborator served for a studio writes one staff flag; a third writes nothing new`.
  - mapping: `round-trips every S27 doc, including null fields and nested pay`; extend #131's shared `chat round-trips every field` test with a `collab`-kind chat and the shared `round-trips Booking through Firestore conversion` test with `assigneeKind: 'collaborator'` and `assigneeAccepted` (cross-plan review finding 41).
  - capacity (S26 Decision 26, owner 2026-10-07): `a pending collaborator offer leaves the booking in unassignedIds; acceptance moves it to assignedIds and books the collaborator's day`; `an active collaborator adds no capacity: a studio whose members are all busy refuses a new booking (day_taken)`.
  - `errors.test.ts`: `collab_full → resource-exhausted`, `recruit_blocked → failed-precondition`, `a field error carries details.field` (if not already covered by the jobs plan) (+ any S26 code added here).
  - `seed_fixtures.test.ts`: `seeds one open collaborator post by Cúc Studio with matchKeys and filterKeys from the domain`; `seeds an applied application by An`; `seeds an active collaboration Cúc–Dũng with defaultFee 600000 and both counters`.
- [ ] **Step 2:** `cd app_flutter/firebase/functions && npm test` → fail.
- [ ] **Step 3: Implement** adapters (Admin SDK transactions: every `tx.get` before the first write), callables (`requireUid` + `run(operation, fn)` like `callables/award.ts`), trigger wiring (`onDocumentCreated({...TRIGGER_OPTIONS, document: 'recruitPosts/{postId}'})`), and the seed (computed with the domain helpers, not hand-written keys). `seed/README.md`: one line per seeded S27 item and which account sees what (Lan the customer sees no "Tuyển thợ" and no "Đang tuyển"; Bình sees the post and "Xác minh để ứng tuyển").
- [ ] **Step 4: Rules** (sample; adapt to the S26 assignee branch names):
  ```
  function isProviderAccount() {
    return signedIn()
      && get(/databases/$(database)/documents/users/$(request.auth.uid)).data.get('role', null) == 'photographer'
      && exists(/databases/$(database)/documents/photographers/$(request.auth.uid));
  }
  match /recruitPosts/{postId} { allow read: if isProviderAccount(); allow write: if false; }
  match /recruitApplications/{appId} {
    allow read: if signedIn() && (resource.data.applicantId == request.auth.uid || resource.data.studioId == request.auth.uid);
    allow write: if false;
  }
  match /studio_collaborations/{id} {
    allow read: if signedIn() && (resource.data.studioId == request.auth.uid || resource.data.collaboratorId == request.auth.uid);
    allow write: if false;
    match /history/{h} {
      allow read: if signedIn() && (get(/databases/$(database)/documents/studio_collaborations/$(id)).data.studioId == request.auth.uid
        || get(/databases/$(database)/documents/studio_collaborations/$(id)).data.collaboratorId == request.auth.uid);
      allow write: if false;
    }
  }
  match /collab_jobs/{id} {
    allow read: if signedIn() && (resource.data.studioId == request.auth.uid || resource.data.collaboratorId == request.auth.uid);
    allow write: if false;
  }
  match /staff_flags/{id} { allow read, write: if false; }
  // bookings/{id}/private/contact, assignee branch (S26) gains:
  //   && (b.get('assigneeKind', 'member') != 'collaborator' || b.get('assigneeAccepted', false) == true)
  //   && !(b.get('completedAt', null) != null && request.time > b.completedAt + duration.value(7, 'd'))
  //   && !(b.get('cancelledAt', null) != null && request.time > b.cancelledAt + duration.value(7, 'd'))
  ```
  Add `'recruitMatchKeys'` to `photographerServerFieldsUntouched()`. Rules tests (written, not run): `provider (individual, unverified) can get and list recruitPosts`; `studio can list recruitPosts`; `customer cannot get or list recruitPosts`; `customer-mode account with a photographers doc cannot read recruitPosts`; `signed-out cannot list recruitPosts`; `nobody writes recruitPosts, recruitApplications, studio_collaborations, collab_jobs, staff_flags`; `applicant and studio read an application, another provider cannot`; `the two parties read a collaboration and its history, a third cannot`; `customer cannot read collab_jobs`; `another photographer cannot read collab_jobs`; `owner cannot write photographers/{uid}.recruitMatchKeys`; `owner reads photographers/{uid}/private/recruit, cannot write it`; `pending collaborator cannot read the customer contact`; `accepted collaborator can`; `replaced collaborator cannot`; `accepted collaborator cannot read it 7 days after completedAt`.
- [ ] **Step 5: Indexes** exactly as in the Contract.
- [ ] **Step 6:** `npm test && npm run build` (functions) and `cd packages/domain && npm test` → green. Ledger: rules tests written, not run (CI); no Functions integration test added.
- [ ] **Step 7: Commit** `feat(functions): S27 recruit and collaboration callables, rules, indexes and seed [#151]`.

### Task 6: App data — repositories, providers, chat kind, icons, notification visuals

**Files:**
- Create: `app_flutter/lib/data/recruit/recruit_post.dart`, `recruit_repository.dart` (+ `FakeRecruitRepository`), `firestore_recruit_repository.dart`, `recruit_providers.dart`; `lib/data/collab/collaboration.dart`, `collab_repository.dart` (+ `FakeCollabRepository`), `firestore_collab_repository.dart`, `collab_providers.dart`, `collab_csv.dart`; `test/support/recruit_world.dart`
- Modify: `lib/data/chat/chat.dart` (+ its Firestore parser: `ChatKind.collab`), `lib/core/theme/app_icons.dart` (`handshake`, `campaign`, `eventRepeat`; #138's visuals of the S27 types use them), `lib/l10n/app_vi.arb` (error keys + `chatKindCollab`)
- Test: `test/data/recruit/recruit_mapping_test.dart`, `recruit_filter_test.dart`, `recruit_error_test.dart`, `test/data/collab/collab_mapping_test.dart`, `collab_csv_test.dart`, `test/data/chat/` (kind parse case), `test/data/recruit/area_sync_test.dart`

**Interfaces:**
- Consumes: Firestore shapes and callables of Task 5.
- Produces: the Dart contract (models, repositories, providers, `recruitFilterKey`, `recruitMatchScore`, `collabCsv`, `RecruitErrorCode` mapping from `details.code` with fallback to the message, like `bookingErrorOf`).

- [ ] **Step 1: Contract check** (app side); ledger differences.
- [ ] **Step 2: Failing tests:**
  - mapping: `recruitPostFrom parses every field`; `an unknown kind or status drops the row (null)`; `feeHint per_shoot and negotiable`; `applicationFrom`, `collaborationFrom`, `collabJobFrom` (pay nested, `paid_reported` → `PayStatus.paidReported`), `countersFrom` (missing doc → zeros; `postActionsLeft` is 5 on a new VN day).
  - `recruitFilterKey matches the domain format` (same cases as the TS test); `recruitMatchScore 2/1/0`.
  - `area_sync_test.dart`: `builtInAreas ids equal RECRUIT_AREAS ids in packages/domain/src/recruit_areas.ts` (read the TS file text, regex the ids, like `rules_catalogue_sync_test.dart`).
  - errors: `every server code maps to its RecruitErrorCode; unknown → unknown; FirebaseFunctionsException unavailable → network`.
  - `collabCsv`: `header in Vietnamese, one row per job, quotes commas and quotes, amounts as plain integers, VN dates d/M/yyyy`.
  - chat: `kind collab parses to ChatKind.collab`.
  - visuals: `recruit_* and collab_* types get work/handshake icons with tones` (`collab_assignment_offer` action, `*_result` declined/expired muted, accepted success, `collab_pay_disputed` danger, `collab_pay_due` action).
  - `FakeRecruitRepository` / `FakeCollabRepository` record calls (`calls`) and support `failWith` like `FakeAwardRepository`.
- [ ] **Step 3:** run `flutter test --no-pub --timeout 60s test/data/recruit` (and `test/data/collab`) → fail.
- [ ] **Step 4: Implement.** `FirestoreRecruitRepository.list`: `recruitPosts where status == 'open'` + (`filterKeys array-contains recruitFilterKey(...)` when any filter) or (`studioId ==` when `filter.studioId`), `orderBy createdAt desc`, `limit`, `startAfterDocument(after)`, `.get()`. `openCountOf`: `.count().get()` on `studioId ==` + `status == open`. Callables through `FirebaseFunctions.instanceFor(region: functionsRegion)`. Add arb keys used here, run `flutter gen-l10n`.
- [ ] **Step 5:** `flutter analyze` clean; run the test folders above one at a time → green.
- [ ] **Step 6: Commit** `feat(data): S27 recruit and collaboration repositories [#151]`.

### Task 7: S27.01 list (and S06.01 tab), S27.02 detail, S27.03 apply sheet, S03.01 line

**Files:**
- Create: `app_flutter/lib/features/recruit/recruit_list_view.dart`, `recruit_list_controller.dart`, `recruit_list_screen.dart`, `recruit_card.dart`, `recruit_detail_screen.dart`, `recruit_apply_sheet.dart`, `collab_terms_card.dart`, `recruit_area_label.dart` (area id → `AreaOption.name` short form, specialty id → label)
- Modify: `lib/features/work/work_screen.dart` (segments, Decision 20), `lib/features/photographer_profile/widgets/profile_header.dart` (studio "Đang tuyển" line), `lib/app/router.dart`, `lib/l10n/app_vi.arb`
- Test: `test/features/recruit/recruit_list_test.dart`, `recruit_detail_test.dart`, `recruit_apply_sheet_test.dart`, `test/features/work/work_screen_test.dart` (extend), `test/features/photographer_profile/photographer_profile_screen_test.dart` (extend)

**Interfaces:**
- Consumes: `recruitRepositoryProvider`, `myProviderFactsProvider`, `studioOpenRecruitCountProvider`, `photographerProfileProvider` (studio % from #130), `PostPickerGrid` (own posts), `showAppSheet`, `showConfirmSheet`.
- Produces: `RecruitListView({RecruitFilter initial})` (ScreenCode `S27.01`), `RecruitListScreen`, `RecruitDetailScreen(postId)` (ScreenCode `S27.02`), `showRecruitApplySheet(context, post)` (ScreenCode `S27.03`), `CollabTermsCard({required bool agreed, required ValueChanged<bool> onChanged})`.

**Backend wiring:** list = `FirestoreRecruitRepository.list` (`get`, composite index `status + filterKeys + createdAt`, rules `isProviderAccount()`); detail = `get` + `watchMyApplication` (1-doc listener) + `photographerProfileProvider(studioId)`; apply = callable `applyToRecruitPost`; withdraw = `withdrawRecruitApplication`; S03.01 line = `openCountOf` (count aggregation, only for provider viewers). Runs against the emulators with the Task 5 seed (Bình, An).

**Mock parity:** `#S27.01` (bar subtitle "Công việc", four segments with "Tuyển thợ" last, filter chips, `jcard` layout: kind tag + "Hợp với bạn", title, studio + seal · areas · specialties, fee + frequency · age, the R3 note), `#S27.02` (tag row, display title, studio row with "Xem studio", four rows with their small captions, "Yêu cầu", stats line, single primary "Ứng tuyển"), `#S27.02-unverified` (lock note + "Xác minh để ứng tuyển"), `#S27.03` (message field + counter, samples grid + "n/3", terms card + checkbox, contact note, "Gửi ứng tuyển"), `#S03.01-studio` line "Đang tuyển · {n} tin".

- [ ] **Step 1: Contract check**; ledger differences.
- [ ] **Step 2: Failing tests** (fakes from `recruit_world.dart`, fixed clock):
  - list: `shows the cards with kind tag, title, studio, areas, specialties, fee and footer`; `"Hợp với bạn" only on score-2 posts and they come first`; `a negotiable fee shows "Thoả thuận"`; `choosing an area then a specialty queries the combined filter key`; `"Xem thêm" loads the next page with the last cursor`; `empty filter shows "Chưa có tin tuyển nào hợp bộ lọc."`; `shows "Chỉ thợ ảnh và studio thấy mục này."`; `a studio viewer sees the "Tin tuyển của studio" icon opening /studio/recruit; an individual does not`; `fits 320dp at 1.3x text`.
  - S06.01: `a photographer sees the "Tuyển thợ" segment last and it shows the list`; `the default segment is still "Hôm nay"`; `a customer never reaches WorkScreen` (existing guard; assert no recruit repository call).
  - detail: `verified individual: "Ứng tuyển" opens the sheet`; `unverified: lock note and "Xác minh để ứng tuyển" goes to /verify/start`; `already applied: disabled outline "Đã ứng tuyển · chờ studio" and "Rút ứng tuyển" opens a confirm sheet with a red button`; `accepted/declined show the result line`; `member of the posting studio: "Bạn đang là thành viên của …" and no button`; `studio viewer: "Studio xem được tin nhưng không ứng tuyển."`; `closed post: "Tin đã đóng hoặc hết hạn."`; `there is no share action`; `exactly one AppButton.primary`.
  - apply sheet: `collaborator post shows the three terms and the checkbox; "Gửi ứng tuyển" is disabled until agreed`; `member post shows the member note instead of terms`; `picking a fourth sample is refused, counter shows 3/3`; `message counter stops at 400`; `server invalid_argument with field message.contact shows "Bỏ số điện thoại, Zalo hoặc link ra khỏi nội dung" under the message`; `limit_exceeded shows recruitErrorApplyLimit`; `rate_limited shows recruitErrorRateLimited`; `success closes the sheet and shows "Đã gửi ứng tuyển"`.
  - S03.01: `a provider viewing a studio with 2 open posts sees "Đang tuyển · 2 tin" and it opens /recruit?studioId=…`; `a customer viewer sees no line and the repository count is never called` (Review Focus 1); `zero open posts shows nothing`.
- [ ] **Step 3:** run → fail.
- [ ] **Step 4: Implement.** `RecruitListController` (`AsyncNotifier`): holds filter, pages, cursor; sorts loaded posts by `(score desc, createdAt desc)`. Countdown/relative ages from a clock provider (no real timers in tests). Routes `/recruit`, `/recruit/:postId`. Arb keys of this task + `flutter gen-l10n`.
- [ ] **Step 5:** `flutter analyze`; run `test/features/recruit`, `test/features/work`, `test/features/photographer_profile` (one command each) → green.
- [ ] **Step 6: Commit** `feat(recruit): S27.01 list in Công việc, S27.02 detail and S27.03 apply sheet [#151]`.

### Task 8: S27.04 post form and S27.05 studio posts and applicants

**Files:**
- Create: `app_flutter/lib/features/recruit/recruit_edit_screen.dart`, `recruit_edit_controller.dart`, `studio_recruit_screen.dart`, `studio_recruit_controller.dart`
- Modify: `lib/app/router.dart`, `lib/l10n/app_vi.arb`
- Test: `test/features/recruit/recruit_edit_test.dart`, `studio_recruit_test.dart`

**Interfaces:**
- Consumes: `recruitRepositoryProvider` (`create`, `update`, `close`, `renew`, `watchStudioPosts`, `applicantsOf`, `respond`), `myRecruitCountersProvider`, `myProviderFactsProvider`, `builtInAreas`, `kSpecialties`, `vnd_input.dart`, `photographerProfileProvider` (applicant %), the S24/S02 post thumbnails for samples.
- Produces: `RecruitEditScreen({String? postId})` (ScreenCode `S27.04`), `StudioRecruitScreen({String? postId})` (ScreenCode `S27.05`).

**Backend wiring:** callables `createRecruitPost`, `updateRecruitPost`, `closeRecruitPost`, `renewRecruitPost`, `respondRecruitApplication`; `recruitPosts where studioId == uid orderBy createdAt desc limit 10` (listener, index `studioId + createdAt`); applicants `recruitApplications where studioId == uid and postId == … and status == applied orderBy createdAt desc limit 30` (`get`, refreshed after each respond); counters private doc listener.

**Mock parity:** `#S27.04` (counter line "Còn {n}/3 tin mở", kind radios with hints, title + counter, specialty chips max 4, area chips max 5, frequency segments, fee segments + amount, requirements + counter, the note, primary "Đăng tin"/"Lưu thay đổi"), `#S27.05` (meta line, post cards with tag + status badge + "{n} ứng viên · còn {d} ngày" + text actions, applicants section header with pending count, applicant card: avatar, name + mark, % + shoots, three thumbnails, message, outline "Từ chối" + "Nhận", primary "Đăng tin mới", blocked `warnc`).

- [ ] **Step 1: Contract check**; ledger differences.
- [ ] **Step 2: Failing tests:**
  - form: `create shows "Đăng tin tuyển", "Còn 2/3 tin mở" and both kinds`; `edit shows "Sửa tin tuyển", "Lưu thay đổi" and the kind locked`; `field errors appear under each field on submit` (title 7 chars, no specialty, six areas impossible: fifth chip then sixth disabled, per-shoot without amount); `a phone number in requirements shows the contact error from the server`; `negotiable hides the amount`; `submit calls create with the exact draft and pops to /studio/recruit with "Đã đăng tin"`; `limit_exceeded shows "Studio đã có 3 tin mở."`; `recruit_blocked shows the block message with the date`.
  - studio screen: `lists posts with status badges and "{n} ứng viên · còn {d} ngày"`; `selecting a post lists its applicants`; `"Nhận" on a collaborator post calls respond(accept: true) and removes the card`; `"Nhận" on a member post that fails with membership_conflict shows "{name} đang ở studio khác hoặc đang cộng tác với studio bạn."` (and cooldown, studio_full, collab_full variants); `"Từ chối" calls respond(accept: false)`; `"Đóng tin" opens the confirm sheet with "Đóng tin này?" and a red "Đóng tin"`; `"Gia hạn 30 ngày" hidden once renewed`; `three open posts: primary disabled "Đã đủ 3 tin mở"`; `unverified studio: primary "Xác minh để đăng tin" → /verify/start`; `blocked studio shows the warning and no enabled primary`; `query post=… preselects that post`; `exactly one AppButton.primary`; `fits 320dp at 1.3x`.
- [ ] **Step 3:** run → fail.
- [ ] **Step 4: Implement**; routes `/studio/recruit`, `/studio/recruit/new`, `/studio/recruit/:postId/edit` (studio only: others are redirected to `/recruit`). Arb keys + `flutter gen-l10n`.
- [ ] **Step 5:** `flutter analyze`; `flutter test --no-pub --timeout 60s test/features/recruit` → green.
- [ ] **Step 6: Commit** `feat(recruit): S27.04 post form and S27.05 studio posts and applicants [#151]`.

### Task 9: S27.06 collaboration, S27.07 offer sheet, and the changed S26/S05/S06/S09/chat screens

**Files:**
- Create: `app_flutter/lib/features/collab/collab_screen.dart`, `collab_studio_view.dart`, `collab_member_view.dart`, `collab_controller.dart`, `collab_offer_sheet.dart`, `collab_paid_sheet.dart`, `collab_fee_sheet.dart`, `collab_accept_sheet.dart`
- Modify: the S26 assign sheet (S26.04: groups + fee field), the S26 invite sheet (S26.02: collaborator mode), the S05.02 "Thợ chụp cho bạn" block, S05.02/S06.01 studio-side offer state, `lib/features/work/work_screen.dart` (label), `lib/features/settings/settings_screen.dart` (add rows "Cộng tác" `settings-collab` (photographer) and "Tin tuyển" `settings-recruit` (studio) to group Tài khoản per S09's order (#148 Decision 12): after "Studio của tôi"/"Thành viên studio", before "Xem hồ sơ công khai"), chat list row + chat screen (`ChatKind.collab`), `lib/app/router.dart`, `lib/l10n/app_vi.arb`
- Test: `test/features/collab/collab_studio_test.dart`, `collab_member_test.dart`, `collab_offer_sheet_test.dart`, the S26 assign/invite sheet tests (extend), `test/features/booking/booking_detail_*` (extend), `test/features/work/work_screen_test.dart`, `test/features/settings/settings_test.dart`, `test/features/chat/` (extend)

**Interfaces:**
- Consumes: `collabRepositoryProvider`, `myRecruitCountersProvider`, `myProviderFactsProvider`, `collabCsv`, `Clipboard`, `SharedPreferences` (`collabTaxNoticeSeen:<uid>`), S26 sheets and booking repository (`assignBooking` with `assigneeKind`, `agreedFee`).
- Produces: `CollabScreen({String? offerBookingId})` (ScreenCode `S27.06`; studio → `CollabStudioView`, individual/artist → `CollabMemberView`), `showCollabOfferSheet(context, job)` (ScreenCode `S27.07`).

**Backend wiring:** listeners `studio_collaborations where studioId == uid and status in [invited, active]` / `where collaboratorId == uid …` (indexes from Task 5), `collab_jobs where studioId|collaboratorId == uid orderBy updatedAt desc limit 50`; callables `inviteCollaborator`, `cancelCollabInvite`, `respondCollabInvite`, `endCollaboration`, `setCollabDefaultFee`, `respondCollabOffer`, `reportCollabPaid`, `confirmCollabPay`, `openCollabChat`, `assignBooking`; chat uses existing `sendMessage`. Emulators with the Task 5 seed (Cúc studio ↔ Dũng).

**Mock parity:** `#S27.06` (meta "{a}/{max} cộng tác viên · còn {k} thao tác hôm nay", rows with % + jobs + suggested fee and "…" menu, "Thù lao cần trả" cards with badge + "Đã trả", "Đang chờ" invites with "Huỷ", tax note, "Sao chép bảng kê tháng {m} (CSV)", primary "Mời cộng tác viên"), `#S27.06-me` (Việc chờ nhận with "Còn {time}" badge, Studio cộng tác "{n} / tối đa 5", Lời mời with "Từ chối" / "Xem & nhận", Thù lao with "Chưa nhận" / "Đã nhận", no primary), `#S27.07` (shoot card, studio row, fee row, deadline row, lock note, outline "Từ chối" + primary "Nhận việc"), `#S26.02-collab`, `#S26.04-collab`, `#S05.02-studio-collab`, S06.01 label "Cộng tác · {Studio}", S09.02 rows per the caption.

- [ ] **Step 1: Contract check** (S26 widget names); ledger differences.
- [ ] **Step 2: Failing tests:**
  - studio view: `meta shows 3/5 and actions left; 50 when businessVerified`; `rows show "{jobs} việc đang giao · gợi ý {fee}/buổi"`; `menu "Kết thúc cộng tác" opens a confirm sheet with a red button; member_busy shows "Còn việc được giao chưa xong."`; `menu "Sửa thù lao gợi ý" saves through setDefaultFee`; `menu "Nhắn tin" calls openChat and pushes /chat/<id>`; `"Đã trả" opens the paid sheet; confirm sends the chosen VN date and method`; `due/disputed/reported/received badges`; `tax note shows for a due job of 5.000.000₫ and hides after dismiss (prefs)`; `"Sao chép bảng kê tháng 10 (CSV)" copies collabCsv of that month and shows the SnackBar`; `"Mời cộng tác viên" opens the S26.02 sheet in collaborator mode`; `exactly one primary`.
  - invite sheet (collab mode): `title "Mời cộng tác viên"; dimmed rows with "Thành viên của studio bạn", "Đang cộng tác", "Mời lại được từ {date}", "Chưa xác minh"; "Mời" calls invite`; `5 pending or no actions left disables every "Mời" with the reason line`.
  - photographer view: `pending offer card shows "Còn {time}" and opens S27.07`; `query offer=<id> opens S27.07 on load`; `"Xem & nhận" opens the accept sheet with the terms; confirm disabled until agreed; confirm calls respondInvite(accept: true, acceptTerms: true)`; `"Từ chối" calls respondInvite(accept: false)`; `reported pay shows "Studio báo đã trả {date} ({method})" with "Chưa nhận" (confirm sheet) and "Đã nhận"`; `empty state text`; `no primary button`.
  - offer sheet: `shows shoot, studio, fee, deadline with remaining time from the fake clock`; `"Nhận việc" → respondOffer(accept: true), toast "Đã nhận việc"`; `"Từ chối" → toast "Đã từ chối, studio được báo"`; `deadline_passed shows "Việc này đã hết hạn trả lời"`; `day_taken shows collabErrorDayTaken`; `the sheet shows no customer phone or contact action`.
  - S26.04: `members and collaborators in two groups`; `choosing a collaborator shows "Thù lao" prefilled with defaultFee and the note`; `empty fee shows "Nhập thù lao cho cộng tác viên"`; `primary reads "Gửi việc cho {name}" and calls assignBooking with assigneeKind collaborator and the fee`; `choosing a member keeps S26 behaviour ("Giao cho {name}", no fee)`.
  - S05.02 (customer): `pending collaborator offer still shows the S26 "chưa giao" state, not the collaborator`; `accepted collaborator shows the block with "Cộng tác với {Studio}"`; studio side: `pending shows "Chờ {name} nhận · còn {left}"`, `declined shows "{name} đã từ chối. Giao người khác trước {deadline}."`.
  - S06.01: `an accepted collaborator job shows "Cộng tác · {Studio}"`.
  - S09.02: `photographer sees "Cộng tác" with "{n} studio · {m} việc chờ nhận" → /collab`; `studio sees "Cộng tác" with "{n} cộng tác viên" and "Tin tuyển" with "{n}/3 tin mở" → /studio/recruit`; `customer sees neither`.
  - chat: `a collab chat row shows the label "Cộng tác" and the counterpart name for each side`; `the collab chat screen has no ContactDial and no booking bar`.
- [ ] **Step 3:** run → fail.
- [ ] **Step 4: Implement.** Route `/collab` (providers only). Countdown text via `CountdownText` with the injected clock. Arb keys + `flutter gen-l10n`.
- [ ] **Step 5:** `flutter analyze`; run `test/features/collab`, the S26 feature folder, `test/features/booking`, `test/features/work`, `test/features/settings`, `test/features/chat` one command each → green. Then `dart run tool/affected_test.dart origin/develop --run` → green.
- [ ] **Step 6: Commit** `feat(collab): S27.06 collaboration, S27.07 offer sheet and collaborator assignment [#151]`.

### Task 10: Specs, data model, screen spec, ledger and §2 status

**Files:**
- Modify: `docs/superpowers/specs/2026-10-07-studio-recruiting-design.md` (§5 and §5.1: fee and pay live in `collab_jobs`, Decision 3; §3.2 note on R3 = role + provider doc; status line "đã có plan"), `docs/superpowers/specs/data-model/domain-model.md` (entities RecruitPost, RecruitApplication, StudioCollaboration, CollabJob, enums, invariants: R3, fee privacy, counters), `docs/superpowers/specs/data-model/relational-schema.md` (target tables `recruit_posts`, `recruit_applications`, `studio_collaborations`, `collab_jobs`, booking columns `assignee_kind`, `assignee_accepted`, Firestore mapping rows), `docs/superpowers/specs/components/shared-components.md` (`CollabTermsCard`, recruit card if extracted to core), `docs/superpowers/specs/2026-10-01-remaining-screens.md` (§2 S27 status cells "✅ đã làm (#151) · khớp mock"; §3h.2 ten new rows with icon, filter "Công việc", target)
- Create: `docs/superpowers/specs/screens/recruit.md` (S27.01–S27.07 in the `screens/README.md` template with the strings list = the l10n table), `docs/superpowers/handover/ledger-s27-studio-recruiting.md`

- [ ] **Step 1:** Edit the docs (Vietnamese specs, English code names). Check every string in `screens/recruit.md` against `app_vi.arb` and the mock (grep each key).
- [ ] **Step 2: Ledger:** S26 names actually used and any renames; Decisions 1–25 as rulings; owner questions and their defaults; skipped: rules emulator suite (CI), Functions integration tests, opening the mock in a browser if blocked; deploy order: rules + indexes before Functions (the trigger queries `recruitMatchKeys`; index build can take minutes), then app; a one-off backfill is not needed (`onPhotographerWrite` fills `recruitMatchKeys` on the next profile write; list as a known gap: providers who never edit their profile get no `recruit_post_new` until then; the seed computes keys).
- [ ] **Step 3: Commit** `docs(spec): S27 data model, screen spec, notifications and ledger [#151]`.

## Deferred

- In-app split or payout to collaborators, platform tax withholding (spec §10 option A): needs a lawyer, an accountant and a disbursement partner.
- Studio↔collaborator reviews; percentage fees; paid post boosting; a "manager" role; several photographers on one booking; an employee post kind (spec §10).
- A collaborator-initiated "Xin cộng tác" request (`requested`, `initiatedBy: collaborator`): enum kept, no callable or screen.
- Staff screens: unpaid flags, poaching flags and lifting `recruitBlockedUntil` live in the S23 dashboard (Phase 1.5, #83); until then the console.
- Chat-message contact filtering in booking chats; saving or sharing the CSV as a file (no new package).
- Ranking the 200-recipient fan-out; a backfill job for `recruitMatchKeys`.
- Self-hosted parity: `services/api` migrations and routes for S27 (Phase 2, #90); `relational-schema.md` is the target.
- Legal review of the collaboration terms and of "dịch vụ việc làm" (spec §11) — non-code, owner.
