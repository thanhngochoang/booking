# Handover ledger: S30 organizers, entry tickets, passes and "Đang chụp"

Issue: [#223](https://github.com/thanhngochoang/booking/issues/223) · Branch: `plan/223-s30-chu-su-kien-ve-vao-cua` (from `origin/develop` 5d4fc91f) · Dates: claimed 2026-10-28, closed out 2026-10-29 · One repository, one PR (owner ruling 2026-10-28, see Rulings 1–6).

Spec: `docs/superpowers/specs/2026-10-12-spot-organizer-entry-tickets-design.md`; screens: `docs/superpowers/specs/screens/organizer.md`; plan: `docs/superpowers/plans/2026-10-18-s30-organizer-entry-tickets.md`.

---

## 1. What shipped

A venue becomes an organizer account. It claims an S29 spot (staff-approved), publishes reference entry fees, keeps a list of resident photographers whose guests enter free, sells entry tickets per visit day, invites gate staff and scans QR codes at the gate. A booking at a ticketed spot carries its tickets in the same VietQR payment (a group payment that fans out into held child payments). Every paid booking or ticket has one pass (QR); the photographer's scan moves a booking to the new `shooting` status ("Đang chụp"), the gate's scan checks the ticket in. The automatic `upcoming → shot` step is replaced by the shoot question "Buổi chụp có diễn ra không?". Events declare a venue and consent from the venue manager.

Commits (`git log --oneline 5d4fc91f..HEAD`), by task:

| Task | Commit | Content |
|---|---|---|
| 1 | `c0c9c5d4` | Domain: organizers, spot claims, residents, gate staff, spot access, 11 error codes, 4 notification types |
| 1 | `fc86e43b` | Fix: data-model `recruitMatchKeys` mapping row restored |
| 1b-be | `b335105f` | S21.04 business verification and S06.06 payout account open to organizers (domain and Functions) |
| 1b-be | `5855d31f` | Fix: organizer payout gate, dual-role flags |
| 2 | `3021762a` | Entry events, day capacity (`entry_days`), entry registrations, refunds, release, closed days |
| 3 | `1b35bf8c` | Group payments, bookings with entry tickets, payouts per `(payee, payeeKind)` |
| 3 | `4f4c40a0` | Fix: durable ticket-line refunds, group release guard, waiver on the visit day |
| 4 | `664467d1` | Passes, `scanPass` by scanner role, `shooting`, the shoot question |
| 4 | `bc65d66b` | Fix: denied-shoot exit, due-query paging, waived rescans, used tickets keep money |
| 5 | `160d8a05` | Event venue, venue consent, venue fee |
| 5 | `bcde0c5c` | Fix: venue fee in disputes, published venue edits, group polling |
| 6 | `0d201d44` | 14 callables and Firestore adapters |
| 6 | `2be6a2bc` | Firestore rules, Storage rules, indexes |
| 6 | `6e07399d` | Steps of `bookingClock`, `eventClock`, `rankSpots` |
| 6 | `446c16a0` | Seed, spots CLI, integration tests, data-model rows |
| 6 | `0c7a5bac` | Fix: verified phone lookup, organizer flags from their sources, CLI key guard, event groups |
| 7 | `be2d5aad` | App data: organizer, entry, pass repositories, `PassScanner` port, booking/event/spot extensions |
| 8 | `b4fec748` | S30.01–S30.04, S30.06, S09.02 entry, S12.03-entry |
| 8 (1b-app) | `baf14fc3` | S21.04 and S06.06 entries for organizers |
| 8 | `27c28d33` | Fix: reuse the entry draft on retry, count open gate invites |
| 9 | `67fa53c5` | S30.07, S06.01-scan, the shooting sites |
| 9 | `a5ff7daa` | S30.05, S29.02-entry, S29.04 note, S04.03-entry |
| 9 | `a7e6fc78` | S05.02-pass and askshot, S05.03 keep tickets, S11.04-entry, S04.04 entry |
| 9 | `4a2591e8` | Fix: S30.07 primer, entry refund labels, multi-day tickets, phone check |
| 10 | `0d7d8156` | Rules: the venue manager reads pending events at their spot |
| 10 | `c8808379` | S12.01-venue, S11.02-venue-consent, fee lines, S12.03 venue line |
| 10 | `b09593ea` | Fix: venue reads only after consent is asked, consent-aware states |
| 11 | `0d0cac24` | This ledger and the spec status cells |
| Final | `b53e9f30` | Fix: kept tickets pass the gate, scan attempt budget, gate check-ins for every ticket |
| Final | `381014f0` | Fix: a denied shoot's resolved dispute ends the booking |
| Final | `de9a56c2` | Fix: ranking and spot edits write only their own fields |
| Final | `2f6e7a72` | Fix: entry ticket notices open the buyer's tickets |
| Final | `b9a8e792` | Fix: open entry events sell anywhere, scanner reads again, shooting disputes, day-scoped reads |
| Final | `b17888d0` | Fix: refused scans counted in the scan transaction, legacy codes only on the old callable |

Counts at the end: 14 new callables (9 organizer, 3 entry/venue, 2 scan/shoot), no new Scheduler job (the 10 jobs of `2026-10-07-google-cloud-costs.md` stay), 7 new composite indexes and 3 field overrides (section 6), 11 new error codes and 9 new notification types across the domain (`spot_claim_approved`, `spot_claim_rejected`, `spot_resident_added`, `gate_staff_invited`, `entry_day_closed`, `shoot_question`, `pass_ready`, `event_venue_requested`, `event_venue_answered`). Last full runs: Functions 980/980 after Task 6's fix round; Flutter `+5658 ~42` all passed (Task 8, full affected-test fallback), later folders re-run per task, `flutter analyze --no-pub` clean at every task.

---

## 2. Step 1 findings (contract checks, real names)

Each task re-checked the plan's "Contract with existing code" on the base. Everything below differs from, or adds to, what the plan said.

**Task 1.** `OrganizerStore.expiredResidents(today, limit)` added (`expireResidents` needs a collection-group query). `suspendOrganizer(deps: SuspendOrganizerDeps, actorId, raw, onError?)` takes the event side through `deps.eventPayments`; an ended event is skipped because `cancelEvent` refuses it. `updateManagedSpot` takes a built `cover {url, cardUrl, path}` (the domain cannot build URLs). `pendingClaimsOf(spotId, '*')` (`ANY_ORGANIZER`): a proposal counts as one "spot", so an organizer has one pending proposal at a time. `TRANSPORT_CODE` (`callables/errors.ts:4`) is exhaustive and was completed here; `test/unit/errors.test.ts:16` holds a second exhaustive table. `EventHost.type` gained `'organizer'` here (the plan put it in Task 2). `graphemeCount` is exported from `booking_requests.ts:17`. Notification deep links added to the test port `client_targets.ts`.

**Task 1b.** The role checks the plan names were at `business_verification.ts:36–37` (lookup) and `:60–63` (submit), `verification_use_cases.ts:366–367` and `:519`, `save_payout_account.ts:98`, `payout_account_use_cases.ts:52`, `:105`; all replaced by `businessSubjectOf` and `payoutHolderOf`. `callables/payout_account.ts` has no role check: the check is the domain's `getUserRole` (`payout_firestore.ts:282`). `businessDocs/{uid}/{file}` Storage rule is owner-only, so no change. An old verification document without `subject` reads as `studio`.

**Task 2.** `RegistrationDoc` and `EventRecord` entry fields are optional (absent = null/[]). `EntryFields.startAt/endAt` are day strings; the stored `EventRecord.startAt/endAt` are 00:00 of the first day and 00:00 after the last day (VN). `validateEntryEvent` takes an optional third `options` argument. `closeEntryDay` lives in `event_payments.ts` with deps `EventPaymentDeps & {notify?}`. `LineKind` is defined in `escrow.ts`. `entry_day_closed` is not critical. `stampTicketRelease` (`event_payments.ts:537`) skips payments whose `releaseAfter` is set, so entry payments are stamped at creation. `payoutLineOf` callers: `payout_use_cases.ts:87`, `earnings.ts:186`.

**Task 3.** The booking `createPayment` does not call `newSubjectPayment`; it builds the booking Payment inline (`create_payment.ts:237–334`); `newGroupPayment` wraps `newSubjectPayment`. Reconcile and overdue queries already filter `status == created`, so `awaiting_group` lines are skipped with no query change (plus an explicit filter in `matchPayment`). Signatures that differ from the plan: `bookingEntryDefaults({event, resident, customerItems, today})` returns `{items, providerTicket, waived, amount}`; `groupSettler(deps: BookingDeps, groups = deps.store)`; `GroupLine` has no `eventId`; `Booking.entry` also stores `amount`; `payout_firestore.ts:276` is now `:291` (`providerTypeOf`). #194's spot branch: `BookingDraftInput.spot?` (`create_booking.ts:60`), `buildBookingDraft` (`:121`), `createBookingDraft` (`:172`).

**Task 4.** #136 is merged: `Booking.assigneeId/assigneeKind/assigneeAccepted` and `confirmedAssigneeId` (`collab_jobs.ts:103`) exist; the studio-assignee scan test passes. `TRANSFER_CODE_ALPHABET` is at `payment_code.ts:8`; the plan's example `passCode4 '0420'` is impossible (0 is not in the alphabet), tests use `7K2Q4M9P` → `4M9P`. `findAutoCompletions` (`booking_ports.ts:257`) is repurposed for `shooting` bookings. The paid path is not in `commitTransition`: `depositPaidAt` is set in `booking_payment_paths.ts:59` (`moveDraftToRequested`), called from `handle_transfer.ts:103` and `group_settlement.ts:484`; passes are created there. `checkInRegistration` (old `event_registration.ts:452`), Functions callers `callables/event.ts:174`, `index.ts:1059`. Additions to the Contract types: `PassRecord.eventId`, `ScanPart 'waived'`, `ScanUpdate 'waived_gate'`, `ScanResult.todayCount`, `resolveScan`'s `customerNames`, `BookingEntry.waivedGuests`, `TransitionDecision.shotAt`, `BookingStore.findShootQuestionsDue/findExpiredShootQuestions`, `BookingDeps.random?`. Every `'upcoming'` site in the domain, Functions, rules and the app was listed and decided (t4 list; app sites done in Tasks 7 and 9).

**Task 5.** `respondToHostConsent` (`event_use_cases.ts:569`), `expireHostConsent` (`:599`), `materialChange` (`:117`): venue consent copies their shape in `event_venue.ts` rather than reusing them (host consent is the photographer's, 24 h). `EventRecord.venue` was `{spotId}` only (`event.ts:144`) and `event_firestore.ts` did not map it at all. The Contract's `venueFeeLine(event, quantity)` cannot build a `GroupLine`; real signature `venueFeeLine(event, quantity, {paymentId, registrationId})`. `EventTx.getGroup/putGroup` do not exist; `putGroupView` was added. `EventRecord.venueManagerId` and `saveEventDraft` `hostAs` were added. `groupPass` would have created a pass for a normal-event ticket plus venue-fee group and listed its registration twice; fixed (`groupGetsPass`, dedupe).

**Task 6.** Phone storage is `users/{uid}/private/contact.phone` (E.164) with `phoneVerified` set only by the server; the same numbers also sit in booking and provider contact copies, so the lookup filters by path. No `username` field exists anywhere (`USERNAME_LOOKUP = false`). `live_payments` already registered `payment_group`; no separate `group_settlement_firestore.ts` is needed because `FirestoreBookingStore` implements every `GroupSettlementTx` port. Index count: 143 composite at the base (the Contract's 132 is stale), 150 after (+7), field overrides 4 → 7 (+3). `bookings(status, shootQuestionUntil)` is covered by `(status, shootDeniedAt, shootQuestionUntil)`; `payments(groupId)` is single-field.

**Task 7.** `data/prefs` is only `sharedPreferencesProvider` (`lib/data/prefs/shared_preferences_provider.dart:6`). Entry events are not `EventDraft`s: a separate `EntryEventDraft` sends days (`entry_tickets.ts:143–190`); edits of a published entry go through `updateEvent` (`event_use_cases.ts:569–581`) → `updateEntryEvent`. #194 `Spot` (`lib/data/spots/spot.dart`) is a hand-written class, not freezed. `HostType.fromCode` mapped everything but `photographer` to `platform`; `HostType.organizer` added. `EventType.values` drives the S11.01 and S12.01 chips (`events_list_screen.dart:266`, `create_event_screen.dart:693`); both use `EventType.listed`. No app `PickedFile` type exists (`image_picker_port.dart:5` has `PickedImage` only), so proofs are JPEG. `PassScanner` gained `Widget preview({errorBuilder})`; `becomeOrganizer` returns `Organizer?`; `RegisterOutcome` is the existing success class, so the refusal is `RegisterRefusal.soldOutDay`. `watchResidents/watchEntryEvent` live on `SpotRepository` (S29.02 reads them too). `screen_brightness` 2.1.11 locked.

**Task 8.** Task 1b-app was folded in. `s3003_kpiToday` and `s1203_dayKpi` use `{entered}` instead of the contract's `{in}` (Dart keyword).

**Task 9.** `scanPass` answers only `{eventTitle, quantity, kind}` (plus `todayCount`, `waived`), which limits the S30.07 detail line. `myEventRegistrationProvider` returns the first active registration of an event (wrong for multi-day entry tickets; S04.04 falls back to `myTicketsProvider`).

**Task 10.** A `watchEvent(id).first` re-read did not resolve in the widget-test fake zone, so the publish controller decides "Chờ địa điểm đồng ý" from what it knows (see Deferred minors). No `rules_catalogue_sync_test` covers `events`.

---

## 3. Decisions 1–20 as taken

1. **Base.** #194 is merged and extended in place. #299 had not landed: built in this repo, one PR (owner ruling 2026-10-28). Deviation: Task 6b and the `backend.lock` pin dropped.
2. **Organizer is a document.** As planned. `EventHost.type 'organizer'` landed in Task 1; `isEventManager` accepts the organizer host (Task 2); gate staff are not managers. `organizers suspend <uid>` cancels every open, not-ended event of the organizer (organizer-hosted only; entry events refund only unused tickets, Decision 11). Deviation: suspension keeps `spots.managedBy` and `managedSpotIds` (Ruling 7).
3. **Selling needs a business.** As planned (Task 1b). Deviations: an organizer may save a payout account only after the business is approved (`not_eligible` otherwise); a `review` decision (no bank lookup) also sets `payoutAccountOk`; a dual-role user (provider and active organizer) gets organizer flags too; flags are recomputed only from their sources (`verifications/{uid}.business` approved; `payoutAccounts/{uid}` holder name key equals the business name key), never from stored organizer flags; `organizers sync <uid>` repairs after a revoke; a suspended organizer is `conflict` on S21.04 and `permission_denied` on S06.06; an organizer household code with no identity match goes to staff review.
4. **Spot claims.** As planned. CLI: `claims list [--status]`, `claims approve <id> [--spot <spotId>]`, `claims reject <id> --reason …` (a rejection without reason is allowed). Deviations: the app picks JPEG proofs only (Storage and server still accept PDF/PNG ≤ 10 MB); an organizer has one pending proposal at a time; approving a suspended organizer's claim is `conflict`; approving on an archived spot is `spot_archived`; `claims approve --spot` writes in two transactions; Storage proof read is admin-only like the Firestore rule.
5. **Residents and waivers.** As planned (≤ 50, `acceptsOrders` only, `expireResidents` in `rankSpots`). Deviations: `waiverFor` is evaluated on the visit day, not today (Ruling 13); `maxGuests` must be 1–100; `saveResident` checks blocks in either direction; waived guests hold no registration and do not count against `dailyCapacity` (Ruling 14).
6. **Payment lines = group payment.** As planned, with these differences: `PAYMENT_STATUSES 'awaiting_group'`, `Payment.groupId/lineKind/payeeKind`, `payment_groups/{gid}` read model (payer reads only); `groupSettler(deps: BookingDeps, groups)`; one group per ≥ 2 lines, all-waived keeps a direct booking payment (no `entry` is sent); group expiry keeps the booking draft until its own draft sweep (Ruling 12); `confirmFakePayment` on a line confirms its group; a partial transfer refunds, children stay `awaiting_group`; the same group mechanism also carries `event_ticket` + `venue_fee` lines (Task 5). The `lines`-array reading of spec §5.2 was not used (Needs the owner 1).
7. **Pass codes.** As planned: 8 characters from `TRANSFER_CODE_ALPHABET`, `VE-XXXX-XXXX` display, `isPassCode`, `passCode4`/`ticketCodeLast4` = last 4 random characters, legacy `VE-XXXX-MMDD` resolved through `ticket_codes`. Additions: `PassRecord.eventId` (one pass never spans two events), `passes/{code8}.waivedCheckedInAt` (server-only) for waived-only gate check-ins. A booking-only pass is created when the booking is paid alone, a group pass when the group is paid, a lone entry ticket pass when its registration is paid. **Alphabet note (spec §6.1):** spec §6.1 shows `VE-7K2Q-0420` with the date in the last four characters; the code does not (the last four are random), per this decision.
8. **Pass privacy.** As planned for bookings and entry tickets (`private/pass`, customer or buyer only; `passes/*` closed). Deviation: normal-event tickets keep their public `VE-XXXX-MMDD` `ticketCode` and `ticket_codes` row, because spec §6.1 says normal-event registrations keep `ticketCode` and the manager scans them (Ruling 19); only entry tickets moved to the private pass. A normal-event ticket in a venue-fee group gets no pass (Task 5 `groupGetsPass`). S12.03's list shows `ticketCodeLast4` (or the last 4 of a legacy code). The app prefers `private/pass` and caches it in prefs for offline use.
9. **Scanning by role.** As planned (`scanPass`, `resolveScan`). Additions: gate rights come from the organizer, its active `gate_staff` row, the host of a waived booking's entry event, or the manager of a normal event's `venue.spotId` spot; a waived-only gate scan returns success with the waived head count and writes only `entry_days.checkedIn` and `scansToday`; `checkInRegistration` is kept for old clients (manager only) and maps the new codes back; its window is `startAt − 2 h … endAt + CHECKIN_GRACE_HOURS` (spec §6.2 says "tới `endAt`", the existing grace was kept).
10. **`shooting` and the shoot question.** As planned. Details: `scan` is photographer-only (or the confirmed studio assignee), window start − 2 h … end + grace; `mark_shot` needs `shooting` only when `passCode4` is set; `shooting` joins every "active" list (contact, disputes, reminders, app buckets); cancel from `shooting` is `not_eligible`; the sweep step "auto mark-shot upcoming" is gone, `findAutoCompletions` now moves `shooting` bookings to `shot` at end + 24 h, `askShootHappened` sends the question for `upcoming`, `expireShootQuestions` marks `shot` after 48 h. `answerShootHappened(false)` sets `shootDeniedAt`; a denied shoot has a terminal path (Ruling 15). Disputes: `disputeWindow` accepts `shooting` and `upcoming` with `shootDeniedAt` (whole held payment frozen).
11. **Entry events.** As planned. Differences: entry fields on `EventRecord`/`RegistrationDoc` are optional; `closeEntryDay` refunds only unused tickets (Ruling 18) plus late-cancelled held tickets of that day; `cancelEvent` on entry refunds only unused tickets; `activeRegistrationOf(eventId, userId, visitDay?)`; public lists exclude entry events by dropping them after the read (no new index; a page can be shorter, `countCreatedSince` can undercount); `updateEvent` entry rules (a sold type can only be hidden, capacity under a day's tickets is `invalid_argument dailyCapacity`, a day with tickets cannot be closed by an edit, spot immutable).
12. **Entry refunds, release, payouts.** As planned: `entryRefundPercent`, `entryReleaseAt`, `PayeeKind`, `feeBp.organizer = 0`, `taxRateBpOf('organizer') = 0`, `createPayouts` groups by `(payeeId, payment.payeeKind ?? lookup)` and creates one payout per kind (a dual-role first payout creates two `needs_approval` batches). `createPayout` still returns the first batch.
13. **No new job.** As planned. `bookingClock`: `askShootHappened`, `expireShootQuestions`, a denied-shoot dispute step (Ruling 15); `eventClock`: `expireVenueConsent`, `refundClosedDays` (inside the refund step); `rankSpots`: `expireResidents` (first, in its own try). Gate invites expire on read/respond, no sweep.
14. **Which bookings get a pass.** Package, quote, spot and slot bookings paid after the deploy; instant bookings (#140) never get a pass (`bookingGetsPass`); bookings paid before the deploy have no pass and keep "Đã chụp xong" enabled; the shoot question still applies to them.
15. **Booking with tickets.** As planned (`entry` on `createBookingDraft`, `bookingEntryDefaults`, group payment, S05.03 "Giữ vé vào cửa"). Deviation: the app offers S04.03-entry only for bookings from a spot schedule or spot (typed places carry no coordinates; `spotCoversPoint` is built and tested but unused) (Ruling 32).
16. **Venue on events.** As planned (`Event.venue`, `venueConsent`, 72 h, `respondVenueConsent`, `venue_fee` line to the manager). Deviations: the fee must be strictly below the price (a 0 ticket line breaks `assertLinesSum`; Decision 16 wrote "above the price"); a published event at an accepted managed spot keeps its consent: a capacity increase is free, a capacity cut with tickets is `venue_consent_required`, a date/deadline/price edit keeps the older `conflict` refusal (it fires first), with no tickets sold or held a material edit returns the event to draft with consent pending; replacing an accepted managed venue on a published event is `venue_consent_required venue`; `VENUE_REQUIRED_FROM` stays `2026-10-19T00:00:00.000Z` in code (move it at merge, section 6); `EventRecord.venueManagerId` stores the accepting manager; the fee is part of the ticket price (mock caption says added on top, see section 4).
17. **Terms text.** `ORGANIZER_TERMS_VERSION = '2026-10-18'`; `app_flutter/assets/terms/organizer_terms_vi.md` and `public_place_commitment_vi.md`, marked "Bản nháp, chờ luật sư". The terms tick in S12.01-venue has no link to the asset.
18. **Scanner port.** As planned: `PassScanner` in `lib/core/scan/` (`mobile_pass_scanner.dart` is the only `mobile_scanner` import); additions `preview({errorBuilder})` and `openSettings()`; `ticket_scanner.dart`, `checkin_sheet.dart` and `fake_ticket_scanner.dart` were deleted, their tests moved to `test/features/scan/`. Offline passes via prefs key `pass.{bookingId|regId}`.
19. **New dependency.** `screen_brightness: ^2.1.0` (locked 2.1.11), only in `core/scan/brightness.dart` behind `ScreenBrightness`; tests use `FakeScreenBrightness`.
20. **Copy.** `organizer.md` keys verbatim; the mock wins where they differ (section 4). Keys whose spec text ends in "…" carry the mock's full sentence.

---

## 4. Copy and layout differing from `organizer.md` or the mock

**S30.01–S30.04, S30.06, S12.03-entry, S09.02 (Task 8)**
- `s3002_review`, `s3003_offApp`, `s3004_note`, `s3006_scope`: the spec text ends in "…", the keys carry the mock's full sentence; `s3004_refundNote` is shown verbatim under the first sentence of the mock note.
- `s3003_kpiToday` "Hôm nay: bán {sold} · vào {entered} · giữ {held}" is one line (held = tickets, not money); the mock draws three tiles (Hôm nay / Đã vào / Đang giữ 12,7M). Same for S12.03-entry: one `s1203_dayKpi` line.
- S30.03: "Sự kiện ở đây chờ bạn đồng ý" was omitted in Task 8 and built in Task 10. A "Tài khoản nhận tiền" row and primary state were added (business verified, no payout account). Primary per tab: "Tạo/Sửa vé vào cửa" (or the missing selling step) on Vào cửa, "Lưu" on Thông tin, none on Thợ tại điểm.
- S30.02: after sending, the screen stays on S30.02 with the "Đang chờ staff duyệt" band (spec says → S30.03, which needs `managedBy`, set only on approval). Proofs are photos only.
- S30.04: open/close are typed `HH:mm` fields; "Ngày nghỉ lẻ (lịch tháng)" is chips plus a date picker (≤ 30); pickers bound the range; day labels are `01/11` (mock `1/11`).
- S30.06: invited row "mời {n} giờ trước" without the phone; names from `users/{uid}`; the mock's "@quocbao" is not shown (no username field); `@username` input answers "Không tìm thấy tài khoản" while the field keeps the copy "Số điện thoại hoặc @username".
- S12.03-entry: the "…" menu "Huỷ cả đợt bán" is not built.
- S09.02: the frame has no organizer row; a new group `organizer` ("Tổ chức sự kiện") after Thông báo and before the payments group; several managed spots open the first one; "Soát vé · {spot}" names the organizer's first managed spot.

**S30.05, S30.07 and variants (Task 9)**
- `s3007_today` uses `{entered}`. S30.07 success detail is "{event title} · {code}" (mock lists ticket types; the scan answer has no types). "rung … (tắt được)": no toggle (short/long haptics only). already_checked_in has no "kèm người quét".
- S30.07 camera primer: the shared `PermissionPrimer` has a gradient primary "Mở cài đặt", against "S30.07 has no gradient button". Kept because the spec asks for the shared primer; all other S30.07 buttons are outline.
- S30.05: no pay-method selector (bank QR by default); sold-out state reads each chip's `entry_days` (≤ 14 small reads per open).
- S04.03-entry: one counter per visible type; the two-payee note is the contract's short sentence, not the mock's longer text; all waived sends no `entry`.
- S05.02-pass: the app puts the card above the booking card (mock shows it instead); `s0502_askOpen` reopen button added.
- S06.01-scan: a pass booking's today card replaces "Chỉ đường" by "Quét mã khách"; legacy bookings keep "Chỉ đường".
- S11.04-entry: the cutoff label uses 48 h (the registration snapshot carries no `refundCutoffHours`); past the cutoff "Đã qua mốc huỷ" (contract text `s1104_pastCutoff`, not the mock's "Không hoàn sau {mốc}"); "Ngày đóng cửa · đang hoàn 100%" only when `entry_days.closed` for the visit day, else a neutral "Đang hoàn 100%" (a key not in `organizer.md`); the tab label `ticketsTab` changed from "Vé sự kiện" to "Vé".
- S02.06 spot-filter variant skipped (no spot filter on S02.06 on this branch).

**S12.01-venue, S11.02-venue-consent, fee lines (Task 10)**
- The mock caption says the venue block replaces the "Điểm chụp" tile: the block is placed under the name and the S29 spot tile stays inside it (the venue's `spotId` is the event's S29 `spotId`).
- Option hints "Cần chủ điểm đồng ý", "Khu du lịch, công viên", "Không thu phí" are mock-only (new keys `s1201_venue*Hint`). Amount label keeps `s1201_feeAmount` "Giá tham khảo (₫)" (mock: "Phí vào cửa tham khảo / người").
- Consent title: the mock "Tổ chức tại {spot}?" wins over "Sự kiện xin tổ chức tại {spot}" (`s1102_consentTitle`).
- **Consent note: the mock caption says the fee is added on top of the ticket price (350k + 50k = 400k); the app follows Decision 16 (fee inside the price), copy `s1102_consentBody`. The mock should be fixed by the owner.**
- No `#S11.02-fee` / `#S11.03-fee` frame: lines follow `organizer.md` copy (`s1102_feeIncluded`, `s1102_feeNotIncluded`, `s1102_venueFee`); S11.02 shows a ticket-icon info row under "where", S11.03 under the phone row and money table.
- Entry-fee line per kind: managed spot "Đã gồm vé vào cửa"; public no line; paid place per the host's choice (not included without an amount: no line).
- S12.03 venue status words come from new select keys `s1203_venueConsent` and `s1203_venueStatusNoFee`; `s1102_consentDeclined` is unused.
- New keys not in `organizer.md` (all in one appended `app_vi.arb` block): `s1201_amountRequired`, `s1201_managedSpotRequired`, `s1201_spotNotManaged`, `s1201_spotManaged`, `s1102_priceWithVenueFee`, `s1102_consentMeta`, `s1102_pricePerTicket`, `s1102_consentBody`, `s1102_consentLeft`, `s1102_consentFeeLocked`, `s1102_consentFeeFree`, `s1102_consentFeeTooHigh`, `s1102_consentExpired`, `s1102_consentDeclineBody`, `s1102_consentAccepted`, `s1102_consentDeclinedDone`, `s1102_consentRespond`, `s1203_venueStatusNoFee`, `s1203_venueConsent`, `s3003_pendingMeta`, plus `statusShooting` "Đang chụp", `eventTypeEntry` "Vé vào cửa" (Task 7) and 108 supporting keys in the Task 9 block. New icons: `AppIcons.qrScanner`, `AppIcons.flashlight`, `AppIcons.park`.

**Notification copy (Task 1, chosen by the implementer, no spec text):** `spot_claim_approved`, `spot_claim_rejected`, `spot_resident_added` (tab `system`), `gate_staff_invited` (tab `events`), all category `events`, none critical, reusing `s3006_inviteTitle` "{org} mời bạn soát vé" and `s3002_managedError`. Later types: `entry_day_closed` (not critical), `shoot_question` (critical), `pass_ready`, `event_venue_requested` (critical, an unanswered request cancels the event), `event_venue_answered`. Review in Needs the owner.

---

## 5. Skipped suites

- **Rules tests** (`app_flutter/firebase/rules-test/rules.test.mjs`: the "S30 organizers, entry tickets and passes" block with 10 tests, plus the venue-manager read tests of Task 10): written, not run.
- **Storage rules tests** (claim proofs, manager cover): written, not run.
- **Functions integration tests** (`test/integration/entry_tickets.test.ts` 5 + 1 cases, `scan_pass.test.ts` 4, and the Task 6 fix-round case for an event-store venue-fee group): written, not run.
- CI runs them. On 2026-10-29 the Firestore and Storage rules were loaded once in the emulator without compile errors; this is not a test run.
- The Firestore `list` rule for the venue manager (Task 10) calls `get()` on `resource.data.venue.spotId` and relies on the query's equality filter being provable: CI must confirm.
- Run and green: domain `npm test/lint/typecheck`; Functions `npm run lint && typecheck && test && build` (980/980 after Task 6's fix round); Flutter folders per task and the full affected-test fallback (`+5658 ~42`); `flutter analyze --no-pub` clean.

---

## 6. Deploy order (this repo, no booking-be)

The dev project is on Spark: emulators only (`BLAZE_ENABLED` off). Functions and Storage deploy only behind `BLAZE_ENABLED`. Order for a Blaze project:

1. **Firestore indexes** (`app_flutter/firebase/firestore.indexes.json`; they take time to build, deploy first, wait until `READY`). New composite indexes (7, from `git diff 5d4fc91f -- app_flutter/firebase/firestore.indexes.json`):
   - `events(status, venueConsent, venueConsentExpiresAt)`: the venue-consent expiry sweep.
   - `events(type, spotId, status)`: S29.02-entry and S30.03 (the entry event on sale at a spot).
   - `events(venue.spotId, venueConsent)`: S11.04-adjacent venue requests, S30.03 pending requests.
   - `bookings(status, disputeId, shootDeniedAt)`: the denied-shoot dispute sweep.
   - `bookings(status, shootDeniedAt, shootQuestionUntil)`: expired shoot questions.
   - collection group `registrations(visitDay, status)`: the day's paid tickets (S12.03-entry, closed days).
   - `spot_claims(status, createdAt)`: `claims list`.
   New field overrides (3; each keeps collection ASC/DESC plus the collection-group scope): `private.phone` (gate-staff phone lookup), `residents.validUntil` (`expireResidents`), `gate_staff.staffUid` (the invitee's invite list).
2. **Functions** (14 new callables, trigger `onPassCreated`, extended `bookingClock`, `eventClock`, `rankSpots`).
3. **Firestore rules and Storage rules** (`firestore.rules`, `storage.rules`). Rules before the app: old clients keep working (a normal event ticket still writes its public code).
4. **App.** The app must ship with the Functions: it reads `shooting` (an old app would read a scanned booking as `draft`).
5. **`VENUE_REQUIRED_FROM`** (`packages/domain/src/event_venue.ts:44`) is `2026-10-19T00:00:00.000Z` in code. Move it to the production deploy date when merging: old app clients cannot publish new events after that date (every non-entry event created at or after it needs a venue). Dev and emulator events need the venue field (S12.01 builds it in this PR).
6. **Staff CLI** (Phase 1 tool, S23/#164 comes later): `scripts/spots-local.sh claims list | approve <id> [--spot <spotId>] | reject <id> --reason …`, `scripts/spots-local.sh access <spotId> --type open|ticket|none [--fee "Label=70000"]… [--note …]`, `scripts/spots-local.sh organizers suspend <uid>` and `organizers sync <uid>` (actor `--actor seed-staff-admin` locally). On real projects the CLI needs `PAYOUT_ACCOUNT_KEY`; the committed emulator key is used only when `FIRESTORE_EMULATOR_HOST` is set. `suspend` prints `cancel failed: <eventId> (<code>)` and exits non-zero on failures.

No new Scheduler job: the 10 jobs of `2026-10-07-google-cloud-costs.md` stay.

---

## 7. Data migration notes

- Old events read `venue: null`; `venueConsent` is written `not_required` by default. They are not asked for a venue again.
- Old registrations keep their public `ticketCode` (legacy, read-only) and their `ticket_codes` rows; `scanPass` and `checkInRegistration` still resolve them. New entry tickets write no public code.
- Bookings paid before the deploy have no pass: no "Mã gặp thợ", "Đã chụp xong" stays enabled, they get the shoot question at end + 24 h (the old automatic `shot` step no longer runs for `upcoming`). The question sweep looks back 14 days and reads at most 1000 documents (a long clock outage can miss older ones).
- `bookings` in `accepted`/`upcoming` mid-flight at the deploy are unaffected except for the sweep change above; none is `shooting` until a pass exists.
- Old S21.04 verification documents without `subject` read as `studio`.
- Instant bookings (#140) never get a pass.
- Payments: no migration; `payeeKind` is absent on old payments (lookup as today). `payments(groupId)` is automatic.
- Postgres/self-hosted parity (phase 2, #90/#180) is not part of this PR; the data-model docs were updated with Tasks 1–5 (`domain-model.md`, `relational-schema.md`, `README.md`).

---

## 8. QA with the seed

Start the emulators (`scripts/backend-local.sh`), seed, then `scripts/spots-local.sh rank`. Accounts and data (`app_flutter/firebase/functions/seed/README.md`, section "Chủ sự kiện & vé vào cửa (S30, #223)"):

1. **Organizer:** sign in as `bai.da.organizer@seed.test` ("Bãi đá sông Hồng", can sell). S09.02 "Địa điểm của tôi" → S30.03 (tabs Vào cửa / Thợ tại điểm / Thông tin); the entry card of `seed-event-entry-bai-da` (types "Người lớn" 70.000₫, "Trẻ em" 40.000₫, 300 a day); S30.04 edit; S30.06 invite Dũng's phone; S12.03-entry "Đóng ngày này".
2. **Customer buys:** sign in as Lan or Minh. S29.02 of `seed-spot-bai-da` shows "Vào cửa", "Bán bởi Bãi đá sông Hồng", "Mua vé" → S30.05 → S04.04 (fake rails: `confirmFakePayment`) → S11.04 shows the QR.
3. **Lan's seeded ticket:** `seed-registration-lan-entry`, tomorrow, pass `VE-VAQC-SEED`; Dũng's scan today answers "Vé ngày …" (`wrong_day`); the list shows `SEED`.
4. **Booking with a pass:** `seed-booking-lan-an-pass` (Lan ↔ An, resident with both waivers, today 15:30–17:30). S05.02 as Lan shows "Mã gặp thợ"; as An from 13:30, S06.01 "Quét mã khách" → `/scan?booking=` with `VE-BKNG-SEED` (manual entry works) → "Đang chụp"; then "Đã chụp xong". Bình's scan is `not_your_pass`.
5. **Gate staff:** sign in as Dũng (invited/active): S09.02 "Soát vé · Bãi đá sông Hồng" → S30.07; only title and today's count, no revenue or contact.
6. **Booking with tickets:** Lan books a provider who is not a resident at the spot from a spot schedule (S29.02 → S04.03-entry); one VietQR pays booking and tickets; decline/expire refunds both lines 100%.
7. **Venue consent:** An or another host creates an event at the managed spot (S12.01-venue "Cần chủ điểm đồng ý"), publishes; the organizer gets `event_venue_requested` → S11.02 consent sheet; accept with a fee below the price.
8. **Shoot question:** move a seeded `upcoming` booking's end more than 24 h into the past and run `bookingClock`: the customer gets `shoot_question`; "Không diễn ra" opens S18.01 with "Buổi chụp không diễn ra".
9. **Staff CLI:** `claims list`, `access seed-spot-ho-tay --type ticket --fee "Người lớn=50000" --actor seed-staff-admin`, `organizers suspend seed-organizer-bai-da --actor seed-staff-admin` (refunds unused tickets 100%); claims are made in the app (S30.02), the seed has none.
10. **Offline:** open a pass (S05.02-pass or S11.04-entry), go offline, reopen: the QR is drawn from the prefs cache.

---

## 9. Rulings during execution

Every `Ruling:` line of the SDD progress ledger, in order, each with its cost if wrong. Where the progress ledger did not state a cost, it is marked "(cost derived)".

Pre-flight
1. Build in this repo's current layout, one PR into develop, #299 later (owner decision 2026-10-28; the plan said stop if #299 had not landed, the owner was asked and chose this). Cost if wrong: #299 moves more files.
2. Task 6b (booking-be API `HTTP_STATUS`/domain shim) dropped; it is a cross-unit request for #299 (map the eleven new codes and `shooting` when the API starts importing the domain). Cost if wrong: booking-be typecheck breaks at #299 time, one small mapping commit.
3. `backend.lock` pin bump dropped (no pin exists before #299). Cost: none.
4. Task 1 Step 1's "#299 landed" check replaced by this layout ruling. Cost: none.
5. Task 3's "settle: exact total → … one pass" assertion moves to Task 4 (`pass.ts` is created in Task 4, which already tests "a paid group gets one pass"). Cost if wrong: one test moved.
6. Run order 1, 1b-be, 2, 3, 4, 5, 6, 7, 8 + 1b-app, 9, 10, 11 (the plan's own split of 1b). Cost: none.

Task 1
7. `suspendOrganizer` keeps `spots.managedBy` and `managedSpotIds` (no release path): spec §3.1 only says cancel and refund events, and a suspended organizer is refused by manager actions anyway. Cost if wrong: staff need a later CLI `spots release`. Owner item.

Task 1b
8. An organizer may save a payout account only after the business is approved (`not_eligible` otherwise); the `review` decision (no bank lookup) still sets `payoutAccountOk` like providers today, first payout staff-approved. The brief requires a match against the business legal name; `review` matches S06.06's existing provider behaviour. Cost if wrong: owner wants matched-only, one line in `save_payout_account.ts`. Owner item.
9. A dual-role user (provider + active organizer) also gets organizer flags: business approval of a verified studio who is an active organizer patches `organizers/{uid}.businessVerified`, and a payout save by such a user sets `payoutAccountOk` when the holder passes the business-name check (the brief says "provider or active organizer" and `becomeOrganizer` allows providers). Cost if wrong: an extra flag write.

Task 2
10. Organizer-hosted ordinary events (priced → `business_required`, free → active; `lineKind event_ticket`, `payeeKind organizer`) go to Task 5, which already edits `event_use_cases` for venue; no task named them. Cost if wrong: none, just placement.
11. `closeEntryDay` also refunds 100% the late-cancelled (`refundPercent 0`, payment still held) tickets of that day, like `cancelEvent`'s `late` set; Task 3 owns day-closed refund plans. Cost if wrong: the organizer loses forfeited late-cancel money on closed days.

Task 3
12. Group expiry keeps the booking draft until its `payableUntil` draft sweep (same as a single booking payment today); Decision 6's "releasing the draft hold" is met by the existing sweep. Cost if wrong: a draft day stays blocked a few minutes longer.
13. `waiverFor` is evaluated on the visit day, not today (re-graded minor, fixed now): a residency ending before the visit would waive tickets the gate should charge. Cost: none.
14. Waived tickets hold no registration and do not count against `dailyCapacity` (residents' guests enter on the resident arrangement, spec E3); a gate scan of a booking pass whose entry has waivers returns success with the waived head count and writes only `scansToday`/`entry_days.checkedIn`. Cost if wrong: the owner may want waived guests counted in capacity.

Task 4
15. A denied shoot ("Không diễn ra") gets a terminal path: photographer `mark_shot` is refused while `shootDeniedAt` is set (legacy bookings too), and a `bookingClock` step opens the dispute as the system with the preset reason "Buổi chụp không diễn ra" when `shootDeniedAt` + 48 h passes with no dispute; keeps the plan's app flow (S18.01 opened by the app) and puts money in the staffed dispute path. Cost if wrong: the owner may prefer opening the dispute immediately in `answerShootHappened`.
16. `findShootQuestionsDue` queries `status == upcoming && shootQuestionAt == null` ordered by day with an end bound (+ an index, along with `bookings(status, shootQuestionUntil)`); `findAutoCompletions` gets `orderBy('day')` and a `day <= bound`; avoids page starvation. Cost: two composite indexes.
17. A waived-only gate check-in marks the server-only `passes/{code8}.waivedCheckedInAt`; a rescan is `already_checked_in` (extends the earlier waived ruling without touching the booking). Cost if wrong: none (staff can still let people in manually).
18. `closeEntryDay` (and its clock retry) refunds only unused tickets (`{unusedOnly: true}`) and the scan refuses entry tickets of a closed day (refunded), consistent with Decision 11's `cancelEvent` rule and the used-ticket rule. Cost if wrong: the owner wants used tickets refunded on a mid-day closure.
19. Normal-event tickets keep writing the public `VE-XXXX-MMDD` `ticketCode`; only entry tickets moved to the private pass (Decision 7 gives passes to bookings and entry tickets only; a normal event's manager scans their own tickets). Cost if wrong: Decision 8's literal wording (all new registrations) needs the normal-event path changed. Owner item.
20. `expireShootQuestions`/`askShootHappened` must not abort `runBookingSweeps` before escrow releases (isolated with try/catch, re-graded minor, fixed now): a failing new query would stop money release. Cost: none.

Task 5
21. Published event at an accepted managed spot: a capacity increase is allowed without new consent; any material edit (date, hours, capacity cut, price) while no ticket is sold or held returns the event to draft with `venueConsent` pending (spec §7.2); with tickets sold or held the edit is refused `venue_consent_required`. Cost if wrong: the owner wants sold events to go pending too (needs a refund flow).
22. The venue fee must be strictly below the price (a 0 ticket line breaks `assertLinesSum`); Decision 16 said "above the price". Cost: a fee equal to the price is impossible. Owner item.
23. `checkTicketPayment` on a fee ticket polls the group (the registration's `paymentId` is an `awaiting_group` line), otherwise the "Kiểm tra thanh toán" fallback never confirms; the host cannot replace an accepted `managed_spot` venue on a published event (`venue_consent_required venue`), keeping the manager's fee and gate (re-graded minor, fixed now). Cost: none.
24. `VENUE_REQUIRED_FROM` stays `2026-10-19` in code; the owner must move it to the production deploy date at merge (old app clients cannot publish new events after it). Cost if wrong: dev/emulator events need the venue field (Task 10 builds it in this PR).
25. Date/deadline/price edits on a published event with tickets keep the pre-existing `conflict` refusal (it fires before `venue_consent_required`; the older rule already forbids those edits for every event with registrations); only capacity cuts reach the venue branch. Cost if wrong: the error code differs from Ruling 21's wording.

Task 6
26. The seed's paid booking Lan ↔ Bình uses a verified, accepting provider (An) instead of Bình if Bình is not (the global rule "only verified, approved providers receive orders" beats the plan's seed wording). Cost: seed names differ from the plan (`seed-booking-lan-an-pass`).
27. Gate staff invites resolve by verified phone only (no username field exists; `@username` → `not_found`). Cost: S30.06 copy mentions @username; owner item.

Task 7
28. Spot-claim proofs are JPEG only in the app (no document picker dependency; server and Storage still accept PDF): adding `file_picker` is a new dependency outside the plan. Cost: an organizer must photograph a PDF contract. Owner item.

Task 8
29. The S30.03 "Sự kiện ở đây chờ bạn đồng ý" section and the spot manager reading a pending-venue draft (`event_venue_requested` → `/e/:id`) move to Task 10 (rules let the venue manager read events whose `venue.spotId` they manage; repository query on `events(venue.spotId, venueConsent)`; the S30.03 section; the consent sheet needs the same read). Cost: none.
30. An entry draft orphaned by leaving S30.04 after a failed publish and re-entering is accepted: drafts are never listed to customers, S30.03 gates "Tạo vé vào cửa" on `canSell` so `business_required` is rare. Cost: a stray draft row per abandoned attempt.

Task 9
31. TDD order slip (S30.07, S06.01-scan, S29.02-entry, S29.04 coded before tests) accepted: the reviewer read the tests and they assert real behaviour. Cost: no RED evidence for those parts.
32. S04.03-entry is offered only for bookings from a spot schedule or spot (typed places have no coordinates; `spotCoversPoint` is built and tested, unused). Cost: a typed place inside a ticketed spot shows no ticket card. Owner item.
33. The S02.06 spot-filter variant is skipped (no spot filter on S02.06 on this branch). Cost: deferred.
34. S11.04 "Ngày đóng cửa · đang hoàn 100%" only when `entry_days.closed` for the visit day; any other `refundDue` shows a neutral "Đang hoàn 100%" (a new key, not in `organizer.md`). Cost (derived): a closed-day refund of a day whose `entry_days` row is not yet read briefly shows the neutral line.
35. Past-day unscanned entry tickets use the visit day for `over` (no big QR after the day); the "within 2 s" scan test tightened; `items: []` in a booking entry request is checked against the server and guarded (re-graded minors, fixed now). Cost: none.

Task 10
36. The venue manager reads an event at their spot only once consent was asked (`venueConsent` in pending, accepted, declined, expired; answered states stay readable for the notification link), never `not_required`: the request is the moment the host shares the event. Cost: none.
37. Overdue not-yet-swept venue requests show as expired (not "hết hạn sau 1 giờ"); `invalid_argument` `spotId` is mapped by venue kind (`managed_spot` without a manager → `s1201_spotNotManaged`) (re-graded minors, fixed now). Cost (derived): a managed spot that is only too far also reads "not managed" (no client radius discriminator; see Deferred minors).

Final review
38. The pass code brute force (the booking shows `passCode4`, the last 4 of 8 characters, and `scanPass` had no attempt limit) is closed with a budget: 20 refused scans (`not_found`, `not_your_pass`) per scanner per hour, counted in the scan's own transaction in `scan_attempts/{uid}` (server-only). A spent budget answers `limit_exceeded`, a real code included. The old `checkInRegistration` takes legacy ticket codes only. Decision 7/8's `passCode4` stays. Cost if wrong: replacing `passCode4` with a `hasPass` flag is a small follow-up.
39. An open entry event at a spot shows "Mua vé" and the tickets in the booking sheet, whatever `spot.access.type` says (spec §3.3 over the plan's test line), through one helper, `Spot.ticketedWith`. Cost if wrong: an organizer whose spot staff marked "open" can still sell tickets.
40. A denied shoot (`upcoming` + `shootDeniedAt`) ends when its dispute is resolved. Any refund moves it to `cancelled` by the system; a release-only outcome moves it to `completed`, in the same transaction. The normal cancel side effects are skipped, because the shoot day has passed and the dispute settles the money. Cost if wrong: one transition to change.
41. Ticket `pass_ready` and `entry_day_closed` notifications open `/bookings?tab=events` (a server target change; the app allowlists exactly that query). Cost if wrong: a photographer who bought tickets lands on their Today view.
42. S12.03-entry and S30.04 read registrations of the selected or upcoming days only. A ticket type sold only on past days is not pre-flagged "Ẩn loại vé"; the server still refuses its deletion. Cost if wrong: one refused save.
43. The final reviewers' "declined to judge" items stand as built:
   - Gateway refunds of group children: fake rails only.
   - A suspended organizer's payouts and cover uploads: Ruling 7.
   - The public read of `entry_days`, and phone-to-name lookup on S30.06: spec choices.
   - Re-reads of denied bookings by the shoot-question job: about $0.2/month at (c).
   - Deleting an organizer account: not in the plan.
   - `becomeOrganizer` reads flags outside its transaction: repaired by `organizers sync`.
   - No partial-transfer UI.
   - No `hostAs` choice in S12.01.
   Cost if wrong: separate follow-ups.

---

## 10. Needs the owner

From the rulings:

- **Suspension keeps `managedBy`** (Ruling 7): staff need a later CLI `spots release` to free the spot. Built by default: kept.
- **Organizer payout rule** (Ruling 8): `review` also sets `payoutAccountOk` (first payout staff-approved). Switch to matched-only if wanted (one line).
- **Household business code with no identity match** goes to staff review, not auto-reject; **dual-role user** whose later account mismatches the business name keeps `payoutAccountOk` (never cleared); a company business refuses company-named accounts for dual-role users (identity check): product call.
- **Own decisions not in the spec** (Task 1): fee label 1–40 graphemes, `maxGuests` 1–100, one pending proposal per organizer, notification copy, categories and tabs of the four S30 notification types (and the later ones).
- **Waived guests are not counted in `dailyCapacity`** (Ruling 14).
- **Denied shoot opens the dispute 48 h after the answer** (Ruling 15), not immediately.
- **Normal-event tickets keep the public `VE-XXXX-MMDD` code** (Ruling 19); Decision 8's literal wording would change the normal-event path.
- **Venue fee strictly below the price** (Ruling 22).
- **`VENUE_REQUIRED_FROM`** must be moved to the production deploy date at merge (Ruling 24).
- **Gate staff invites by verified phone only; `@username` is not resolved** (Ruling 27). The S30.06 copy still says "Số điện thoại hoặc @username".
- **JPEG-only claim proofs** in the app (Ruling 28).
- **S04.03-entry only for spot-schedule bookings** (Ruling 32); S02.06 spot filter skipped (Ruling 33).
- **The mock `#S11.02-venue-consent` caption says the fee is added on top**; the code follows Decision 16 (inside the price). Fix the mock.
- **`shotAt = endsAt`** when set from the shoot question closes the shot dispute window early (the shoot milestone is still held 24 h).

From the plan's "Needs the owner" and what was built by default:

1. Grouped payments with one transfer code instead of a `lines` array inside one Payment (spec §5.2). Built: grouped payments (milestones, payouts, refunds and earnings untouched). The spec text of §5.2 now carries a note (Decision 6).
2. Instant bookings (#140) get no pass in Phase 1 (Decision 14). Built: yes.
3. Suspending an organizer cancels and refunds every open event (spec §3.1), CLI only. Built: yes; unused entry tickets only.
4. Draft terms texts ship marked "bản nháp" until the lawyer's version (spec §13). Built: drafts, version `2026-10-18`.
5. A scanned (`shooting`) booking whose photographer never taps "Đã chụp xong" moves to `shot` by itself at end + 24 h. Built: yes.
6. The venue fee is part of the ticket price, not added on top; a free event at a managed spot cannot carry a venue fee. Built: as written (consent sheet locks the fee at 0 for free events).

From the final review:

- **The scan budget of 20 refusals an hour applies to the gate too.** A busy gate that scans many wrong or foreign passes can be paused for up to an hour. Options: raise it for gate staff and organizers, or keep 20.
- **A denied shoot ended by its dispute keeps the bundled entry tickets paid.** A normal system cancel would refund unused tickets 100%. Options: refund them as well, or keep them.
- **The booking-write trigger sends a system-cancel notice next to the dispute's result message** when a denied shoot is cancelled.

---

## 11. Deferred minors

Condensed from every `minor (deferred)` line of the SDD ledger.

**Task 1.** `suspendOrganizer` `onError` defaults to a no-op and returns only a success count (the CLI passes `onError`). The test "two approvals of one spot at once" does not assert writes. `saveResident` provider lookups run before the manager check (leaks provider existence). `removeResident` does not require an active organizer. `avatarUrl` and the proof path `claimId` segment are unchecked. Own decisions not in the spec (see Needs the owner). `managedSpotIds` is documented in three places in `relational-schema.md` (redundant, consistent).

**Task 1b.** `otp.ts` phone fallback to `users/{uid}/private/contact` applies to every caller and ignores `phoneVerified`. A household code plus organizer with no identity match goes to staff review (product call). The business name is read outside the save transaction (tiny staff-gated window). A double blank line in `payout_account_use_cases.test.ts`. `payoutAccountOk` is never cleared for a dual-role user who later switches to a mismatching account. Dual-role plus company business: identity check refuses company-named accounts, so the organizer flag is reachable only when names agree or via review.

**Task 2.** `updateEntry` openHours edits do not update existing tickets' `event.startAt/endAt` (stale hours on S11.04). The `entry_days` counter clamp `Math.max(0, …)` hides drift. The `event_soon` reminder re-reads entry events before filtering them out. `dispute_firestore` `providerName` was null for organizer hosts (fixed in Task 6 with the organizer's name). `event_use_cases.ts` grew to 605 lines; entry branches could move to `entry_use_cases.ts`.

**Task 3.** `settle` never calls `assertLinesSum` or checks `child.status` is `awaiting_group` in the paid path. Circular import `create_payment.ts` ↔ `group_settlement.ts`. `payer_history` keeps a group row next to line rows when an excess is refunded. `memory_booking_store` linked event sub-transaction can leave half-written memory state on throw (tests only). A dual-role first payout creates two `needs_approval` batches. `domain-model.md` Waiver row and the `organizer.ts:114` parameter still say `today` (now the visit day). `refundTicket` drops a pending `refundDue` silently when the payment is not held (pre-existing).

**Task 4.** `shotAt = endsAt` closes the shot dispute window early when set from the shoot question. No test pins dispute-while-`shooting` then end + 24 h sweep keeps money frozen. Scan tests missing: waived count > 1, waived plus registration on one pass, cancelled entry event (the entry branch of `assertRegistrationPart` skips the cancelled check). `pass_scan.ts` is 498 lines (`runScan` ~150 lines, double `parts.find`). The event scan window ends at `endAt + CHECKIN_GRACE_HOURS`, the spec says `endAt`. `closeEntryDay` still flags used tickets `refundDue` and sends them `entry_day_closed` although money is kept (misleading notice). `findAutoCompletions` and `expireShootQuestions` share one try. `findShootQuestionsDue` has a 14-day lookback and a 1000-read cap (long clock outage). `findDeniedShootsDue` retries permanently failing system disputes every tick. The Firestore path of `openDisputeAsSystem` (`liveDisputeDeps`) is untested.

**Task 5.** Two `awaiting_account` refunds per bank-QR fee ticket (the rider is sent to the paying account after `confirmBy`; S22.04 shows two rows). Contract deviations the app handles: `venueFeeLine(ref)`, `EventRecord.venueManagerId`, `saveEventDraft` `hostAs`, `respondVenueConsent` `deadline_passed`, `publishEvent` returns ok when it only sent a consent request (the app must re-read). "Venue changed?" is a `JSON.stringify` key-order check. `createdByRole` is `photographer` for organizer hosts. `parseEntryFee` defaults `included: true` for public and managed_spot (UI must branch on kind). `readVenue` reads the spot twice. Inline expiry in `respondVenueConsent` is untested. The Functions mapping was not test-first. `pickSubjectPayment` JSDoc is displaced by `venueLinesAmong`. Raising capacity to unlimited (null) is treated as a decrease. A redraft keeps the old `venueFeePerGuest`/`venueManagerId` while pending. A republish rewrites the group chat `event_{id}`. An idempotent `resolveDispute` retry returns `lineRefunds []` (`resendPendingRefunds` is the fallback).

**Task 6.** `claims approve --spot` writes in two transactions. The Storage spot-claim proof read allows `staffIs('admin')` only (Contract said `isStaff()`), matching the Firestore rule. The spot counter runs an extra unbounded query per spot daily. `liveRankSpotsDeps` builds all `liveOrganizerDeps`. Manager cover uploads are unbounded. Metadata-probe noise in `npm test`. `spotCoverOf` `cardUrl` is the full cover. The phone lookup page cap (`LOOKUP_PAGES`, 10 × 50) could miss a second verified owner of a number held in more than 500 contact copies. `seed/README.md:84` "An earnings" description is stale. A venue-fee ticket group settled by the Firestore settler is covered by a unit test on `MemoryFirestore` and a written, not run, integration case.

**Task 7.** Lines over 80 columns in `booking.dart`, `spot.dart`, `firestore_nearby_events_repository.dart` (no CI format gate). S11.01 pages can be short (entry rows are filtered after the read) and `countCreatedSince` can undercount. The `canPhotographerComplete` check ordering. `EntryItem/EntryLine/OpenHours` live in `organizer.dart` and are imported by booking, events and spots. `pass_scanner` ↔ `mobile_pass_scanner` circular import and `core.dart` exporting a file that links `mobile_scanner`. The `spot_entry_reads_test` name contradicts its assertion. A stale `notification_visuals_test` comment. `PluginScreenBrightness` has silent catches.

**Task 8.** State is mutated in `build` behind once-flags (entry edit, managed spot, apply screen). `verify_business_screen` flashes the needs-identity alert while `myOrganizerProvider` loads. `OrgBadge` light colours in dark mode. Resident search is limited to the ≤ 200 candidates pool. `managed_spot_screen` opens for any spot id (the server refuses writes). Large screen files (578/543/457 lines). `s3003_pendingEvents` (built in Task 10). `_invite(int live)` parameter name. An expired invite badge still reads "Đã mời". The fake `inviteGateStaff` overwrites an active staff row (test support). `/organizer/payout-account` reuses `PayoutAccountScreen` copy ("verified name").

**Task 9.** `bookingEntryInfoProvider`/`quoteBookingEntry` mirror the domain's `bookingEntryDefaults` in Dart (a parity fixture test is advisable). `_EntryNote` wording for a resident without a provider waiver. The entry-error colour token family. The `_ctl.start` post-frame flicker. `scan_screen` `_gateSpotId` is the first managed spot. The small "Mua vé" primary on S29.02 against provider cards. `entryBuyPath` duplicates `spotTicketsPath`. No `DetailAction.answerShoot` in the action table. The "closes after 3 s" test does not assert still open at 2.9 s. Unformatted edited files and large files (`review_step` +230, `work_screen` +190, scan/entry_buy ~390). The S11.04 cutoff/label flickers while event/entry_day load. Entry events show "join" even when `paymentsReady` is false. An empty `SizedBox` in the entry join bar. `myEventRegistrationProvider` returns the first active registration for multi-day entry events (the event page join bar still uses it). The 48 h cutoff is assumed on S11.04.

**Task 10.** The event page turns `_gone()` after the manager answers. An unnecessary `ref.invalidate(venueRequestsProvider)`. The terms tick has no link to the terms asset. An `invalid_argument` `spotId` for a managed spot that is too far now shows "not managed" (no client radius discriminator). Switching the venue kind away and back resets `venueConsent` client-side, giving a wrong waiting toast. The publish controller decides "Chờ địa điểm đồng ý" from known state: if the spot read failed, the toast says "Đã đăng sự kiện" while S12.03 shows the pending line. While the spot read is in flight the venue manager briefly sees the "gone" state.

**Final review.**
- Domain:
  - The booking path does not check `canSell(org)`.
  - A waived head count enters on a closed day.
  - `entry` on a non-spot booking is not refused, and a reschedule leaves tickets on the old day.
  - The booking path counts lapsed holds against `dailyCapacity`.
- Backend:
  - `closeEntryDay` reads the whole event's held tickets.
  - A dual-role (studio) payout save never sets `payoutAccountOk`.
  - Every entry purchase writes the event document (`heldCount`).
- App:
  - A scanned booking with no `at` reads "Vé đã hoàn".
  - S12.03 prints full legacy codes.
  - "Tạo QR mới" fails generically on a closed or sold-out day.
  - `canPhotographerComplete` ignores `shootDeniedAt`.
  - A studio owner sees "Quét mã khách" for a member's booking.
  - The scan screen's shooter line comes from `?booking=`.
  - Ticket lines go stale after `closeEntryDay`.
  - `pass.*` prefs are kept after sign-out.
  - An unknown claim status reads as rejected.
  - `business_required` falls to the generic publish error.
  - Payment-group rows on S22.01 have no title.
  - `paymentGroupProvider` and `payTotalVnd` are dead code.
  - Opening hours cannot be cleared.
- Fix round:
  - With two QR codes in frame, the older one can be sent again.
  - The denied-cancel leaves the customer's own contact snapshot.

---

## 12. Cross-unit requests

- **#299 (backend split, booking-be).** When booking-be's API starts importing this repo's domain: map the eleven new error codes in `HTTP_STATUS` (`src/errors.ts`) — `spot_managed`, `not_spot_manager`, `day_closed`, `sold_out_day`, `not_your_pass`, `wrong_day`, `too_early`, `already_checked_in`, `venue_consent_required`, `business_required`, `refunded` (plus `deadline_passed` where not yet mapped) — and the `shooting` booking status (Postgres `bookings.status` check, API enums). Task 6b was dropped; no `backend.lock` pin was bumped. The data-model docs already list the new tables and columns. The #299 move should also carry `scripts/spots-local.sh`, the seed, the new rules and the 7 indexes.
- **#162 (dashboard foundation) and #164 (S23 staff review).** Collections and callables the organizer web screens and the claim review reuse: `organizers`, `spot_claims`, `reviewSpotClaim` (staff-only, not in the app), `entry_days`. See the comments posted by the controller.
- **#213 (check-in timeline).** `registrations.checkedInAt/gateCheckedInAt`, `entry_days.checkedIn`, `bookings.checkedInAt`.
- **#140 (instant) and #142 (S18), both closed.** Decision 14 (instant bookings get no pass; `mark_shot` stays enabled without a pass) and the S18 preset reason "Buổi chụp không diễn ra" with `shootDeniedAt` (opened by the app from the shoot question, or by the system 48 h after the answer, Ruling 15) are recorded here instead of a comment.
- **#136 and #139.** #136 is merged: the studio assignee scans (`confirmedAssigneeId`). #139 (quotes) is untouched.

## Deferred (outside this PR)

- Organizer screens on the web dashboard (#162, spec §15) and staff claim review in S23 (#164, Phase 1.5); the CLI is the Phase 1 tool.
- Check-in timeline and density map (#213, Phase 2).
- Flat venue fees per event, host → venue (spec §15); ticket time windows enforced at the gate (spec §15); seat maps; external ticket channels.
- Collecting what residents pay the venue (E3).
- Passes for instant bookings (#140, Decision 14) and for bookings paid before this plan ships.
- Lawyer-approved terms and commitment texts (Decision 17, spec §13); the intermediary's multi-payee payout condition (spec §5.2, chosen with the partner).
- A `lines` array inside one Payment if the intermediary cannot split one transfer across payees (Needs the owner 1 revisits Decision 6).
- Self-hosted parity in booking-be (phase 2, #90/#180): API routes and PostgreSQL migrations for `organizers`, `organizer_gate_staff`, `spot_claims`, `spot_residents`, `entry_days`, `passes`, `payment_groups`, and the `shooting` status in the Postgres `bookings.status` check.
- Real payment intermediary, real payouts (fake rails only, owner ruling 2026-10-07).
