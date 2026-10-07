# S18 · Khiếu nại & hỗ trợ (S18.01–S18.03) Implementation Plan

> **Rules emulator tests (2026-10-02, user):** this plan changes `firestore.rules`, `storage.rules` and `firestore.indexes.json` and adds Functions. Write the rules tests and the Functions integration test; do not run them, CI runs them. Record the skips in the ledger.

> **No battery/performance, device build or iOS steps** (standing rules in `RUN-ORDER.md`).

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

> **Detail level (user, 2026-10-02):** exact interfaces, tests listed by name with expected behaviour, sample code only for the parts easy to get wrong.

**Goal:** A customer whose booking or paid event ticket went wrong opens a dispute inside the dispute window (reason, description, up to 5 evidence photos); the money of that booking or ticket stops moving towards the provider at once; customer, provider and support talk in one thread on the dispute screen; staff decide (release / refund / split) through a callable or the staff CLI and the money follows on the fake rails; everyone can read a static FAQ and chat with a support inbox.

**Architecture:** Business rules live in `packages/domain` (new `dispute*.ts` and `support*.ts` modules with ports and an in-memory store, like albums and awards). A dispute is `disputes/{id}` plus one support thread `support_threads/dispute_{id}` (+ `messages/`); the help chat is `support_threads/help_{uid}`. Clients only read; every write goes through the callables `openDispute` (re-pointed to the new use case), `resolveDispute` (staff `admin`), `sendSupportMessage`, or the staff CLIs `npm run disputes` / `npm run support` (Admin SDK, same use cases). Opening freezes the subject's escrow payment (`escrowStatus: disputed`), which the existing `bookingClock` step 5 and the payout CLI already skip; resolving restores it and applies a refund (fake gateway) and/or the existing release. Two triggers (`onDisputeWrite`, `onSupportMessageCreated`) send notifications through the existing `notify` use case. The app gets `lib/data/disputes/` and `lib/data/support/` (Firestore adapters, fakes in `test/support/`), feature folders `features/disputes/` (S18.01 sheet, S18.02) and `features/help/` (S18.03, support chat), and entry points on S05.02, S11.04, S09.02 and notifications. Evidence photos live in Storage `disputeEvidence/{uid}/{disputeId}/{file}`, readable by the parties only.

**Tech Stack:** TypeScript (domain, Functions v2 callables + `onDocumentWritten`/`onDocumentCreated`, `node --test`), Firestore/Storage rules and indexes; Flutter, Riverpod 3, go_router, existing core widgets (`ChatBubble`, `ChatComposer`, `ReasonPicker`, `StatusTimeline`, `EscrowNotice`, `AsyncView`, `EmptyState`, `showAppSheet`, `showConfirmSheet`).

**Spec:** `docs/superpowers/specs/2026-10-01-remaining-screens.md` §2 (S18 rows), §3g (escrow), §3i.1 (S18), §3i.6 (S23 audit rule), §8 questions 3, 16, 18, 22; `docs/superpowers/specs/2026-10-06-payments-payouts-design.md` §4 (milestones, "Khiếu nại → mốc liên quan `disputed`, chi trả `on_hold`"), §5 (refunds); `docs/superpowers/specs/2026-10-06-delivery-preview-unlock-design.md` §4–§5 ("Báo vấn đề với ảnh gốc" → S18.01 with preset reasons); `docs/legal/terms-and-help-notes.md` (FAQ source); `docs/superpowers/specs/data-model/README.md` (`open_dispute`, `resolve_dispute`), `domain-model.md` §5 escrow state machine; mock `docs/design/ui-mock.html` `#S05.06-approved` (entry), frames added by Task 1.

**Issue:** #142. **Blocked by:** #147 (shared image API: `ImagePurpose.document`, `jpegUpTo`) for Tasks 3 and 6; soft coordination with #129/#130 (Decision 1) and #148 (settings rebuild, Task 8). **Branch:** `plan/142-s18-disputes-help`, PR into `develop` titled `feat(disputes): S18 disputes, dispute detail and help [#142]`.

## Contract with existing code

Checked 2026-10-07 on `develop` 812afd6. The first step of every task re-checks the names it uses; adapt and ledger any difference. If a member named here does not exist, stop and report instead of guessing.

- Domain (`packages/domain/src`): `openDispute(deps: BookingDeps, {bookingId, customerId, reason})` in `open_dispute.ts` (allows `upcoming`, 24 h after `completedAt`, freezes the first `held|partially_refunded` payment) — **replaced** by this plan; `MIN/MAX_DISPUTE_REASON_LENGTH` (`booking_policy.ts`, only used there); `DISPUTE_WINDOW_HOURS = 24`; `Payment.dispute?: {reason, openedAt}`; `disputeEscrowPayment`, `applyRefundToPayment({payment, refundId, percent, ledgerEntryId, reason, now})` (percent of `payment.amount`), `releaseEscrowPayment({payment, refundAmount, ledgerEntryId, now})`, `verifyPaymentLedgerInvariant` (`escrow.ts`); `dispatchRefund(deps: BookingDeps, refund, provider)` (`refunds.ts`); `runBookingSweeps` step 5 releases only `held|partially_refunded` with `releaseAfter <= now` (`booking_sweeps.ts`); `PaymentGateway.issueRefund` (`refundId` is the idempotency key), `FakePaymentGateway`; `notify(deps: NotifyDeps, req: NotifyRequest)`, `NOTIFICATION_TYPES`, `renderNotification`, `NotificationContent` (`notification*.ts`); `graphemeCount` (`booking_requests.ts`); `isId`, `DomainError`, `ERROR_CODES` (no new code is added); `PLATFORM_PAYEE`; `Booking` (`booking.ts`, has `completedAt`, `escrowStatus`, no `disputeId`); registrations: `RegistrationRecord` (`event_ports.ts`), `endAt` on the event, ticket payment `subjectType 'event_registration'`, `eventId` on the payment, `releaseAfter = endAt + 24 h` set at completion (`event_payments.ts:416`). Memory stores refuse a read after a write inside a transaction (`memory_album_store.ts` pattern).
- Functions (`app_flutter/firebase/functions/src`): `handleOpenDispute` in `callables/booking.ts:120` and the `openDispute` export in `index.ts:122` (no app code calls it: `BookingRepository.openDispute` is unused); `CALLABLE_OPTIONS`, `PAYMENT_CALLABLE_OPTIONS`, `TRIGGER_OPTIONS` (`config.ts`); `toHttpsError` (`callables/errors.ts`); staff claim read as `request.auth?.token?.staffRole` (`callables/award.ts`); `liveNotifyDeps()` (`infra/live_notification.ts`); `bookingFromFirestore` / the booking writer and the payment mapping with `dispute` (`infra/booking_firestore.ts:175,200`); registration mapping in `infra/event_firestore.ts`; `getSharedFakeGateway()` (`infra/live_booking.ts`); staff CLI pattern `tools/awards.ts` (`parseArgs`, `HELP`, `--actor` with `staffRole == 'admin'`) and its test `test/unit/award_cli.test.ts`; seed `seed/fixtures.ts` (`seed-booking-disputed`: payment `disputed`, no dispute document), `seed/README.md`.
- Rules: no `disputes`, no `support_threads`; catch-all deny. Storage: no `disputeEvidence`; `awardProofs` is the private-upload precedent (create-only, `resource == null`, raster types). Indexes: none on these collections.
- App data: `Booking` (`lib/data/booking/booking.dart`: `completedAt`, `escrowStatus`, `deposit`, no `disputeId`), `BookingRepository.openDispute` + `FirestoreBookingRepository.openDispute` (unused; removed), `BookingRules.canCustomerDispute` + `disputeWindowHours` (`booking_rules.dart:9,137`; allows `upcoming`; replaced), `EventRegistration` (`lib/data/events/event_registration.dart`: `amount`, `status`, `paymentId`, `event.endsAt`), `firestore_event_mapping.dart`; media: `MediaUploader.upload(image, storagePath:)`, `MediaUrlResolver.downloadUrl(path)`, `mediaUploaderProvider`, `mediaUrlResolverProvider`, `imagePickerProvider`, `PickedImage`; `newUlid()` (`lib/core/ulid.dart`); `authStateProvider`, `currentProfileProvider`, `staffRoleProvider`.
- App features: `BookingDetailScreen` + `bookingDetailRoutes()` + `DetailSheet {cancel, decline}` + `_maybeOpenSheet` (`features/booking/booking_detail_screen.dart`), `detailActions` + `DetailAction` (`booking_view_rules.dart`), the red text-button style of the cancel action (`AppColors.destructive` / `AppColorsDark.destructive`), `bookingCode(id)`; S11.04 `TicketCard` (`lib/core/widgets/ticket_card.dart`; `compact`, `onCancel`, `cancelLabel`) built in `features/events/tickets_tab.dart:297`; `SettingsScreen` sections (`features/settings/settings_screen.dart`); `notificationVisualOf` (`features/notifications/notification_visuals.dart`); `eventSupportEmail` / `eventSupportUri` (`features/events/event_links.dart`, used by `event_info_tab.dart:118`, tested in `test/features/events/event_links_test.dart`); `lib/app/router.dart`.
- Core: `ScreenCodes.openDispute` (S18.01), `disputeDetail` (S18.02), `help` (S18.03) already exist (`lib/core/screen_codes.dart:102-104`); `AppIcons.flag`, `AppIcons.lock`, `AppIcons.info`, `AppIcons.schedule`, `AppIcons.addPhoto`, `AppIcons.chat` exist; `help`, `supportAgent` do not.

## Global Constraints

- Spec §3i.1, verbatim: "S05.02 / S11.04 hiện "Báo vấn đề" khi booking `completed` hoặc vé đã dùng và còn trong `dispute_window_hours` → S18.01 → `openDispute` (khoản tiền `held → disputed`, khoản chi trả `on_hold`) → S18.02 theo dõi; nhiếp ảnh gia nhận thông báo, xem S18.02 và gửi giải trình; staff xử lý ở S23.01 (`resolveDispute`: thả / hoàn / chia), hai bên nhận thông báo và tiền đi theo kết quả." "một khiếu nại mở cho mỗi booking hoặc vé; quá cửa sổ thì nút ẩn và S18.03 giải thích; ảnh bằng chứng lưu riêng tư (chỉ hai bên và staff đọc); không có kênh liên hệ ngoài app mới nào được mở vì khiếu nại."
- Spec §3i.6: "mọi quyết định của staff ghi nhật ký kiểm toán (ai, lúc nào, lý do); tiền chỉ di chuyển qua callable phía server, không sửa tay dữ liệu."
- Money (CLAUDE.md, owner ruling 2): money moves only on the fake rails (`FakePaymentGateway`, payout CLI); no real intermediary. Refunds come only from money still held (Invariant 12).
- Delivery spec §5: "nút chữ đỏ "Báo vấn đề với ảnh gốc" (→ S18.01 với lý do điền sẵn: thiếu ảnh, khác ảnh mẫu, link hỏng)".
- Support email: build config `SUPPORT_EMAIL` only (`--dart-define=SUPPORT_EMAIL=…`); unset hides every email line. Never write an invented address.
- CLAUDE.md: business rules in `packages/domain` (no Firebase/Node imports, `purity.test.ts`); Functions thin, region `asia-southeast1`; Firebase only in `lib/data/**` adapters, `firebase_options.dart`, `main.dart`; strings in `lib/l10n/app_vi.arb` + `flutter gen-l10n`; `AppColors`/`AppSpace`/`AppRadius`/`AppIcons` only; `package:photobooking/...` imports, features import `core/core.dart`; one `AppButton.primary` per screen; every screen/sheet wrapped in `ScreenCode`; `AsyncView` for every `AsyncValue`.
- Ids/time/money (`data-model/README.md`): ULID/opaque ids (the client mints the dispute id with `newUlid()`), UTC instants (`Timestamp` in Firestore, ISO strings in the domain), integer VND, string enum codes.
- Commits: Conventional Commits, subject ends with `[#142]`, footer `Co-Authored-By: TonyH <thanhngochoangbk@gmail.com>` (never the Claude line).
- Env for Flutter commands (from `app_flutter/`): `source ../scripts/env.sh && export HOME="$PWD/../.home" && export PATH="$PWD/../.flutter/bin:$PATH"`.
- Tests: `flutter test --no-pub --timeout 60s <file or folder>`, one folder at a time (never the whole suite in one command); bounded pumps (`pump(Duration)`, no `pumpAndSettle` on screens with loaders/countdowns); domain `cd packages/domain && npm test && npm run lint`; functions `cd app_flutter/firebase/functions && npm test && npm run build`; rules-test and Functions integration suites are written, not run (CI runs them).

## Decisions (where the spec is silent)

1. **What a dispute freezes.** The subject's escrow payment that is still held (`held|partially_refunded`). Opening sets it `disputed` and stores `dispute: {reason, openedAt, disputeId, prevEscrowStatus}`; `bookingClock` step 5 (filter `held|partially_refunded`) and the payout CLI (`released` only) already leave it alone, and the earnings trigger already shows "Đang khiếu nại". When #129/#130 split payments into milestones, the freeze moves to the milestone in its window: `findHeldPayment` and `disputeWindow` (Contract) are the two extension points; this plan writes that into the ledger and the issue comments of #129/#130.
2. **Who opens, when.** The paying customer only (`openedBy: 'customer'`; provider-opened disputes from delivery "hết lượt sửa" are #130's, through the same use case with `openedBy: 'provider'`). Booking: status `completed` or `reviewed`, `now < completedAt + DISPUTE_WINDOW_HOURS` (strictly before, the same instant the escrow becomes releasable). The old `upcoming` allowance is dropped: before the shoot the customer cancels (S05.03). Ticket: registration `paid`, `amount > 0`, `endAt <= now < endAt + 24 h`; check-in is **not** required (spec says "vé đã dùng", but "the event did not happen" is the main ticket complaint and leaves the ticket unused). Free tickets hold no money: no dispute; S18.03 says so.
3. **Errors.** Wrong state, free ticket, no held payment → `not_eligible`; window over → `deadline_passed`; a dispute already open on the subject → `conflict`; caller not the payer → `permission_denied`; malformed → `invalid_argument`. No new error code.
4. **Idempotent open.** The client mints the dispute id (`newUlid()`) before uploading evidence (the Storage path needs it) and sends it; a second `openDispute` with the same id by the same customer returns the existing dispute unchanged.
5. **Reasons** (string codes, fixed): booking `no_show`, `not_as_agreed`, `photos_missing`, `not_as_sample`, `link_broken`, `other`; ticket `event_not_held`, `not_as_described`, `other`. Origin `delivery_check` (S05.06, #130) offers `photos_missing`, `not_as_sample`, `link_broken`, `other`. Description is required, 10–1000 graphemes after trim (staff need facts; replaces the old 1–500 reason text). Evidence: 0–5 images.
6. **Evidence storage.** `disputeEvidence/{uid}/{disputeId}/{fileId}.jpg`, fileId a fresh ULID per upload (Storage refuses overwrites, award-proof precedent). Firestore stores paths only, never download URLs (a token URL bypasses rules); viewers resolve URLs with `MediaUrlResolver.downloadUrl`, which the Storage rule checks against `disputes/{id}.parties`. The owner may delete an upload only while no dispute document with that id exists (the sheet cleans up after itself). Kept after resolution; purge with account deletion (S22.02) or a later job (Deferred). **Uploads use the shared image API of #147** (`docs/superpowers/plans/2026-10-07-s10-post-upload.md`): `MediaUploader.upload(image, storagePath:, purpose: ImagePurpose.document)` (2048 px, q85, EXIF removed, JPEG only) and the Storage rule helper `jpegUpTo(3 * 1024 * 1024)`; no PNG/WebP/HEIC on this path. #147 is a dependency of Task 3 (rule helper) and Task 6 (uploader `purpose:`); if it has not landed, stop those steps and report.
7. **Outcome money.** `release` (refund 0%), `refund` (100%), `split` (integer 1–99%). The percent applies to the amount **still held** (`payment.amount − Σ refunds`), `refundAmount = floor(held × pct / 100)`, `releaseAmount = held − refundAmount`. In one transaction: payment back to its `prevEscrowStatus`, then `applyRefundToPayment` with an explicit `amount` (new optional parameter), then `releaseEscrowPayment` when `releaseAmount > 0` (payee: provider, or `platform` which keeps it). The refund is sent through the gateway after the commit (`dispatchDisputeRefund`, same as cancellations); a failed send leaves the refund `failed`/`manual` (S23.03 path). Ticket refunds left `pending` are re-sent by the existing event clock (`refunds (subjectType, status, createdAt)`), harmless because `refundId` is the gateway idempotency key.
8. **Thread.** One thread per dispute, three-party: customer, provider (absent for platform-hosted events) and support. The provider's messages are the "giải trình" of §3i.1. Parties read everything in it; messages are server-written (`sendSupportMessage`); sending closes when the dispute is resolved (`not_eligible`). Opening writes a system message and the customer's description as the first message.
9. **Help chat.** `support_threads/help_{uid}`, created by the first `sendSupportMessage` without a thread id. Staff answer with `npm run support -- reply` until the S23.06 dashboard (phase 1.5, #83). Text only; 1–1000 graphemes; at most 10 messages per sender per thread per rolling 10 minutes (`limit_exceeded`).
10. **Staff side, phase 1.** Callable `resolveDispute` (ID token `staffRole == 'admin'`) and CLI `npm run disputes -- list | show <id> | resolve <id> release|refund|split [percent] "<note>" --actor <uid>`; both call `resolveDispute` in the domain. Audit trail = `outcome.decidedBy/decidedAt/note` on the dispute, the ledger entries (`refund_issued`, `escrow_released`) and the thread system message. No "reviewing" sub-state (staff just reply in the thread).
11. **Notifications** (new types, category `booking`, tab `activity`): `dispute_opened` → provider (critical), `dispute_resolved` → parties (critical), `support_reply` → thread participants when staff write (critical), `dispute_message` → the other party when a party writes (grouped per dispute, not critical). Targets `/disputes/{id}` and `/help/chat`.
12. **Mirrors.** `bookings/{id}.disputeId` (+ the existing `escrowStatus` mirror) and `events/{e}/registrations/{r}.disputeId`, written by the dispute transaction. Both Firestore mappings must round-trip `disputeId`, or the next booking transition would erase it (Review Focus 5).
13. **Entry points.** S05.02 customer, window open: red text button "Báo vấn đề · còn {h} giờ" under the actions (mock `S05.02-problem`); S05.02 any party, `disputeId` set: a banner "Đang khiếu nại" / "Khiếu nại đã có kết quả" → S18.02 (mock `S05.02-disputed`); S11.04 compact past ticket in its window: text button "Báo vấn đề"; S18.03 "Khiếu nại của bạn"; notification deep links; S09.02 new section "Hỗ trợ" → "Trợ giúp". Routes: `/b/:id/dispute` (sheet over S05.02; `?from=delivery` presets the delivery reasons for #130), `/disputes/:id`, `/help`, `/help/chat`. The ticket sheet has no route (opened from S11.04). §2 route cells are updated.
14. **Support email** moves to `lib/core/app_config.dart` (`supportEmail`, `supportEmailUri()`), exported from `core.dart`; `event_links.dart` loses `eventSupportEmail`/`eventSupportUri` and S11.02 uses the new names. S18.03 shows "Email hỗ trợ: {email}" under the button only when set.
15. **FAQ** is static, in `app_vi.arb`, written from `docs/legal/terms-and-help-notes.md` (P1–P10, P12, C1, R1, V1–V2, spec §3i.1) in 7 topics (Task 8 has every string). It states the product rules (100%, two milestones, delivery check) that #129/#130 implement; if this ships first, the ledger notes the temporary mismatch with the app's "cọc" copy. "Chụp ngay" FAQ waits for S13.
16. **Display code.** `#K7Q2` = last 4 characters of the dispute id upper-cased (`disputeCode(id)`, like `bookingCode`).
17. **Seed.** A `disputes/seed-dispute-lan-an` document for the existing `seed-booking-disputed` (open, thread with a staff and a provider message), a completed booking `seed-booking-completed-window` (completed 2 hours before seeding, payment held) to try S18.01, and a past paid ticket for Lan inside its window (`seed-event-an-past-workshop`, ended 3 hours before seeding, `seed-registration-lan-past-paid`, payment held).

## Needs the owner

1. **Three-party thread** (Decision 8): the customer reads the provider's explanation and vice versa. Default: yes. The alternative (two private threads with support) doubles the screens.
2. **Withdrawing a dispute** ("Rút khiếu nại", money back to `held`): default not in this unit (Deferred); staff can resolve with `release`.
3. **Evidence retention**: default kept until account deletion (S22.02); a purge job (e.g. 90 days after resolution, like `purgeAwardProofs`) comes later.

## Contract

### Data (Firestore)

- `disputes/{id}` (server-written only): `id`, `subjectType: 'booking'|'ticket'`, `subjectId` (bookingId | registrationId), `eventId: string|null`, `paymentId`, `customerId`, `providerId` (photographer uid or `'platform'`), `parties: string[]` (customerId, + providerId unless `'platform'`), `openedBy: 'customer'`, `reason` (code), `description`, `evidencePaths: string[]` (≤ 5), `snapshot: {title, subtitle, providerName|null, thumbUrl|null}` (display copy taken at open: booking → `"{photographer} · {service}"`, `"T7 12/10 · 15:30–17:30"`; ticket → event title, `"CN 20/10 · 06:00–09:00"`), `amountHeld` (int VND at open), `status: 'open'|'resolved'`, `outcome: null | {kind: 'release'|'refund'|'split', refundPercent, refundAmount, releaseAmount, note, decidedBy, decidedAt, refundId|null}`, `threadId` (`dispute_{id}`), `createdAt`, `updatedAt`, `resolvedAt|null`, `version`.
- `payments/{id}.dispute`: `{reason, openedAt, disputeId, prevEscrowStatus: 'held'|'partially_refunded'}` (shape extended; server-only as today).
- `bookings/{id}.disputeId: string|null`; `events/{e}/registrations/{r}.disputeId: string|null` (server-only).
- `support_threads/{threadId}` (server-written only): `id`, `kind: 'help'|'dispute'`, `ownerId: string|null` (help: the user), `disputeId: string|null`, `participants: string[]`, `status: 'open'|'closed'`, `awaitingStaff: bool`, `lastMessageAt`, `lastMessagePreview` (≤ 80 graphemes), `lastSenderRole: 'customer'|'provider'|'user'|'staff'|'system'`, `rate: {[uid]: {windowStart, count}}`, `createdAt`, `updatedAt`.
- `support_threads/{threadId}/messages/{messageId}` (id = client ULID; system messages server ULID): `id`, `threadId`, `senderId: string|null` (null for system), `senderRole`, `senderName` ("Hỗ trợ" for staff), `body`, `createdAt`.
- Storage `disputeEvidence/{uid}/{disputeId}/{fileId}`.

### Domain (`packages/domain/src`)

```ts
// dispute.ts
export const DISPUTE_SUBJECT_TYPES = ['booking', 'ticket'] as const;
export type DisputeSubjectType = (typeof DISPUTE_SUBJECT_TYPES)[number];
export const DISPUTE_REASONS = ['no_show', 'not_as_agreed', 'photos_missing', 'not_as_sample', 'link_broken',
  'event_not_held', 'not_as_described', 'other'] as const;
export type DisputeReason = (typeof DISPUTE_REASONS)[number];
export const REASONS_BY_SUBJECT: Readonly<Record<DisputeSubjectType, readonly DisputeReason[]>>;
export const DISPUTE_STATUSES = ['open', 'resolved'] as const;
export type DisputeStatus = (typeof DISPUTE_STATUSES)[number];
export const DISPUTE_OUTCOMES = ['release', 'refund', 'split'] as const;
export type DisputeOutcomeKind = (typeof DISPUTE_OUTCOMES)[number];
export const MAX_DISPUTE_EVIDENCE = 5;
export const DISPUTE_DESCRIPTION_MIN = 10;
export const DISPUTE_DESCRIPTION_MAX = 1000;
export const DISPUTE_NOTE_MIN = 5;
export const DISPUTE_NOTE_MAX = 500;
export interface DisputeSnapshot { readonly title: string; readonly subtitle: string; readonly providerName: string | null; readonly thumbUrl: string | null }
export interface DisputeOutcome { readonly kind: DisputeOutcomeKind; readonly refundPercent: number; readonly refundAmount: number;
  readonly releaseAmount: number; readonly note: string; readonly decidedBy: string; readonly decidedAt: string; readonly refundId: string | null }
export interface Dispute { readonly id: string; readonly subjectType: DisputeSubjectType; readonly subjectId: string;
  readonly eventId: string | null; readonly paymentId: string; readonly customerId: string; readonly providerId: string;
  readonly parties: readonly string[]; readonly openedBy: 'customer'; readonly reason: DisputeReason; readonly description: string;
  readonly evidencePaths: readonly string[]; readonly snapshot: DisputeSnapshot; readonly amountHeld: number;
  readonly status: DisputeStatus; readonly outcome: DisputeOutcome | null; readonly threadId: string;
  readonly createdAt: string; readonly updatedAt: string; readonly resolvedAt: string | null; readonly version: number }
export interface OpenDisputeInput { readonly disputeId: string; readonly subjectType: DisputeSubjectType; readonly subjectId: string;
  readonly eventId: string | null; readonly reason: DisputeReason; readonly description: string; readonly evidencePaths: readonly string[] }
/** Throws invalid_argument. Evidence paths must be `disputeEvidence/{uid}/{disputeId}/{fileId}` with fileId `[A-Za-z0-9_-]{1,64}\.jpg` (JPEG only, #147). */
export function parseOpenDisputeInput(raw: unknown, uid: string): OpenDisputeInput;
/** The window of a subject; throws not_eligible (state) or deadline_passed (closed). Extension point for #130 (`approved` → `checkUntil`). */
export function disputeWindow(subject: DisputeSubjectView, now: Date): { readonly closesAt: Date };
/** Throws invalid_argument (split outside 1–99, percent given for release/refund). */
export function outcomeAmounts(heldAmount: number, kind: DisputeOutcomeKind, refundPercent?: number):
  { readonly refundPercent: number; readonly refundAmount: number; readonly releaseAmount: number };
export const disputeThreadId = (disputeId: string): string => `dispute_${disputeId}`;
export const helpThreadId = (uid: string): string => `help_${uid}`;

// dispute_ports.ts
export interface DisputeSubjectView {
  readonly type: DisputeSubjectType; readonly id: string; readonly eventId: string | null;
  readonly customerId: string; readonly providerId: string;   // 'platform' for platform-hosted events
  readonly state: string;                                      // booking status | registration status
  readonly windowStart: Date | null;                           // booking.completedAt | event endAt
  readonly amount: number;                                     // 0 for a free ticket
  readonly paymentId: string | null;                           // registration.paymentId; null for bookings (looked up)
  readonly disputeId: string | null;
  readonly snapshot: DisputeSnapshot;
}
export interface DisputeTx {
  getSubject(type: DisputeSubjectType, id: string, eventId: string | null): Promise<DisputeSubjectView | null>;
  getDispute(id: string): Promise<Dispute | null>;
  /** Booking: the first `held|partially_refunded|disputed` payment with subjectId = booking id; ticket: `paymentId`. Extension point for milestones (#129/#130). */
  findSubjectPayment(subject: DisputeSubjectView): Promise<Payment | null>;
  setDispute(d: Dispute): void;
  setPayment(p: Payment): void;
  /** Booking: `disputeId` + `escrowStatus` mirror; registration: `disputeId` only. */
  linkSubject(subject: DisputeSubjectView, patch: { readonly disputeId: string; readonly escrowStatus: EscrowStatus }): void;
  addRefund(r: Refund): void;
  addLedgerEntry(e: LedgerEntry): void;
  putThread(t: SupportThread): void;
  addMessage(m: SupportMessage): void;
}
export interface DisputeStore {
  runTransaction<T>(fn: (tx: DisputeTx) => Promise<T>): Promise<T>;
  getRefundsForPayment(paymentId: string): Promise<readonly Refund[]>;
  saveRefund(r: Refund): Promise<void>;
  listByStatus(status: DisputeStatus, limit: number): Promise<readonly Dispute[]>;
}
export interface DisplayNames { displayName(uid: string): Promise<string> }   // '' when unknown
export interface DisputeDeps { readonly store: DisputeStore; readonly gateway: PaymentGateway; readonly names: DisplayNames;
  readonly clock: Clock; readonly ids: IdGenerator }

// dispute_use_cases.ts
export async function openDispute(deps: DisputeDeps, callerId: string, raw: unknown): Promise<Dispute>;
/** Input `{disputeId, outcome, refundPercent?, note}`; the adapter has already checked the staff role. */
export async function resolveDispute(deps: DisputeDeps, staffId: string, raw: unknown): Promise<{ dispute: Dispute; refund: Refund | null }>;
/** After commit: gateway.issueRefund, then saveRefund(done | failed+manual). */
export async function dispatchDisputeRefund(deps: DisputeDeps, payment: Payment, refund: Refund): Promise<Refund>;

// escrow.ts (modified)
// Payment.dispute?: { reason; openedAt; disputeId?: string; prevEscrowStatus?: 'held' | 'partially_refunded' } | null
// applyRefundToPayment gains `amount?: number` (when given: used instead of percent math; must be 1..held; full when Σ refunds == payment.amount)

// support_thread.ts
export type SupportThreadKind = 'help' | 'dispute';
export type SupportSenderRole = 'customer' | 'provider' | 'user' | 'staff' | 'system';
export interface SupportThread { readonly id: string; readonly kind: SupportThreadKind; readonly ownerId: string | null;
  readonly disputeId: string | null; readonly participants: readonly string[]; readonly status: 'open' | 'closed';
  readonly awaitingStaff: boolean; readonly lastMessageAt: string | null; readonly lastMessagePreview: string | null;
  readonly lastSenderRole: SupportSenderRole | null; readonly rate: Readonly<Record<string, { windowStart: string; count: number }>>;
  readonly createdAt: string; readonly updatedAt: string }
export interface SupportMessage { readonly id: string; readonly threadId: string; readonly senderId: string | null;
  readonly senderRole: SupportSenderRole; readonly senderName: string; readonly body: string; readonly createdAt: string }
export const SUPPORT_TEXT_MAX = 1000;
export const SUPPORT_RATE_LIMIT = 10;          // messages
export const SUPPORT_RATE_WINDOW_MINUTES = 10;

// support_use_cases.ts
export interface SupportTx { getThread(id: string): Promise<SupportThread | null>; getMessage(threadId: string, id: string): Promise<SupportMessage | null>;
  getDispute(id: string): Promise<Dispute | null>; putThread(t: SupportThread): void; addMessage(m: SupportMessage): void }
export interface SupportStore { runTransaction<T>(fn: (tx: SupportTx) => Promise<T>): Promise<T>;
  listAwaitingStaff(limit: number): Promise<readonly SupportThread[]>; listMessages(threadId: string, limit: number): Promise<readonly SupportMessage[]> }
export interface SupportDeps { readonly store: SupportStore; readonly names: DisplayNames; readonly clock: Clock; readonly ids: IdGenerator }
/** `{threadId?: string|null, clientId, text}`; null/absent → the caller's help thread (created on first message). */
export async function sendSupportMessage(deps: SupportDeps, senderId: string, raw: unknown): Promise<{ threadId: string; messageId: string }>;
export async function staffReply(deps: SupportDeps, staffId: string, raw: unknown): Promise<{ threadId: string; messageId: string }>;

// dispute_notifications.ts
export async function notifyDisputeChange(deps: NotifyDeps, before: Dispute | null, after: Dispute | null): Promise<void>;
export async function notifySupportMessage(deps: NotifyDeps, thread: SupportThread, message: SupportMessage): Promise<void>;
// notification.ts NOTIFICATION_TYPES gains:
//   dispute_opened: meta('booking','activity',true), dispute_resolved: meta('booking','activity',true),
//   dispute_message: meta('booking','activity'), support_reply: meta('booking','activity',true)
// notification_render.ts NotificationContent gains:
//   { type: 'dispute_opened'; customer: string; subject: string; ticket: boolean }
//   { type: 'dispute_resolved'; subject: string; kind: DisputeOutcomeKind; provider: string; refund: number; release: number }
//   { type: 'dispute_message'; sender: string; preview: string; count: number }
//   { type: 'support_reply'; preview: string }
// memory_dispute_store.ts: MemoryDisputeStore implements DisputeStore, SupportStore (one class; seeded subjects, payments, refunds)
```

Rendered notification copy (server, verbatim): `dispute_opened` title `"{customer} báo vấn đề với buổi chụp"` (ticket: `"{customer} báo vấn đề với vé sự kiện"`), body `"{subject}. Tiền được giữ tới khi có kết quả. Gửi giải trình trong mục Khiếu nại."`; `dispute_resolved` title `"Khiếu nại đã có kết quả"`, body release `"{subject}: tiền được chuyển cho {provider}."`, refund `"{subject}: hoàn {refund} cho khách."`, split `"{subject}: hoàn {refund} cho khách, chuyển {release} cho {provider}."` (amounts with `formatVnd`; platform events: `{provider}` = "ứng dụng"); `dispute_message` title `"{sender} nhắn trong khiếu nại"`, body preview or `"{count} tin nhắn mới"`; `support_reply` title `"Hỗ trợ đã trả lời"`, body preview. Dedupe keys `dispute_opened:{id}`, `dispute_resolved:{id}`, `support_reply:{messageId}`; `dispute_message` grouped with `groupKey: dispute:{id}`, actor = sender.

### Callables and triggers (`asia-southeast1`)

| Name | Input | Output | Errors |
|---|---|---|---|
| `openDispute` (`PAYMENT_CALLABLE_OPTIONS`) | `{disputeId, subjectType, subjectId, eventId?, reason, description, evidencePaths}` | `{disputeId}` | `invalid_argument`, `permission_denied`, `not_found`, `not_eligible`, `deadline_passed`, `conflict` |
| `resolveDispute` (`PAYMENT_CALLABLE_OPTIONS`) | `{disputeId, outcome: 'release'\|'refund'\|'split', refundPercent?, note}` | `{disputeId, refundAmount, releaseAmount}` | `permission_denied` (token `staffRole != 'admin'`), `invalid_argument`, `not_found`, `conflict` (not open / payment not disputed) |
| `sendSupportMessage` (`CALLABLE_OPTIONS`) | `{threadId?: string\|null, clientId, text}` | `{threadId, messageId}` | `invalid_argument`, `permission_denied`, `not_found`, `not_eligible` (dispute resolved), `limit_exceeded` |
| `onDisputeWrite` (`disputes/{id}`, `TRIGGER_OPTIONS`) | before/after | — | `notifyDisputeChange` |
| `onSupportMessageCreated` (`support_threads/{threadId}/messages/{messageId}`) | created message | — | `notifySupportMessage` (reads the thread) |

CLIs (`app_flutter/firebase/functions/tools/`): `npm run disputes -- list [open|resolved] | show <id> | resolve <id> release|refund "<note>" --actor <uid> | resolve <id> split <percent> "<note>" --actor <uid>`; `npm run support -- list | show <threadId> | reply <threadId> "<text>" --actor <uid>`. `--actor` must have the claim `staffRole: 'admin'` (disputes) or `admin|sales` (support), same environment rules as `npm run awards`.

### Rules, Storage, indexes

```
// firestore.rules
match /disputes/{id} {
  allow get, list: if signedIn() && request.auth.uid in resource.data.parties;
  allow write: if false;
}
match /support_threads/{threadId} {
  // A missing help thread must read as "none", not as a denial.
  allow get: if signedIn() && (threadId == 'help_' + request.auth.uid
                               || request.auth.uid in resource.data.participants);
  allow list: if signedIn() && request.auth.uid in resource.data.participants;
  allow write: if false;
  match /messages/{messageId} {
    allow read: if signedIn() && request.auth.uid in
      get(/databases/$(database)/documents/support_threads/$(threadId)).data.participants;
    allow write: if false;
  }
}
// storage.rules
match /disputeEvidence/{uid}/{disputeId}/{file} {
  // purpose: document (#147); JPEG only
  allow create: if isOwner(uid) && resource == null && jpegUpTo(3 * 1024 * 1024);
  allow read: if isOwner(uid) || (signedIn() && request.auth.uid in
    firestore.get(/databases/(default)/documents/disputes/$(disputeId)).data.parties);
  allow delete: if isOwner(uid)
    && !firestore.exists(/databases/(default)/documents/disputes/$(disputeId));
  allow update: if false;
}
```
Indexes: `disputes (parties CONTAINS, createdAt DESC)` (S18.03), `disputes (status ASC, createdAt ASC)` (CLI), `support_threads (awaitingStaff ASC, lastMessageAt ASC)` (CLI).

### App (Dart)

```dart
// lib/core/app_config.dart (exported from core.dart)
const String? supportEmail;                       // from String.fromEnvironment('SUPPORT_EMAIL'); '' → null
Uri? supportEmailUri([String? email = supportEmail]);

// lib/data/disputes/dispute.dart
enum DisputeSubjectType { booking, ticket }
enum DisputeOrigin { booking, deliveryCheck, ticket }
enum DisputeReason {
  noShow('no_show'), notAsAgreed('not_as_agreed'), photosMissing('photos_missing'), notAsSample('not_as_sample'),
  linkBroken('link_broken'), eventNotHeld('event_not_held'), notAsDescribed('not_as_described'), other('other');
  const DisputeReason(this.code); final String code;
  static DisputeReason fromCode(String? c);                              // unknown → other
  static List<DisputeReason> offeredFor(DisputeOrigin origin);           // Decision 5
}
enum DisputeStatus { open, resolved }
enum DisputeOutcomeKind { release, refund, split }
class DisputeOutcome { kind, refundPercent, refundAmount, releaseAmount, note, decidedAt }
class Dispute { id, subjectType, subjectId, eventId, customerId, providerId, reason, description, evidencePaths,
  title, subtitle, providerName, thumbUrl, amountHeld, status, outcome, threadId, createdAt, resolvedAt;
  bool isCustomer(String uid); }
String disputeCode(String id);                                           // last 4, upper case
class DisputeDraft { disputeId, subjectType, subjectId, eventId, reason, description, evidencePaths }
class DisputeError implements Exception { const DisputeError(this.code); final String code; }  // domain code | 'network'

// lib/data/disputes/dispute_repository.dart
abstract class DisputeRepository {
  String evidencePath(String disputeId, String fileId);                 // disputeEvidence/{uid}/{disputeId}/{fileId}.jpg
  Stream<UploadEvent> uploadEvidence(PickedImage image, String storagePath);   // MediaUploader.upload(…, purpose: ImagePurpose.document) (#147)
  Future<void> deleteEvidence(String storagePath);                     // missing object is fine
  Future<String> open(DisputeDraft draft);                             // → disputeId; throws DisputeError
  Stream<Dispute?> watch(String disputeId);
  Future<List<Dispute>> mine({int limit = 10});                        // get, newest first
  Future<String> evidenceUrl(String storagePath);
}
// firestore_dispute_repository.dart: FirestoreDisputeRepository({required String? uid, required MediaUploader uploader,
//   required MediaUrlResolver urls, FirebaseFirestore? db, FirebaseFunctions? functions})
// dispute_providers.dart
final disputeRepositoryProvider = Provider<DisputeRepository>(...);    // rebuilt on uid change (event_providers pattern)
final disputeProvider = StreamProvider.autoDispose.family<Dispute?, String>(...);
final myDisputesProvider = FutureProvider.autoDispose<List<Dispute>>(...);
final evidenceUrlProvider = FutureProvider.autoDispose.family<String, String>(...);

// lib/data/support/support_thread.dart
enum SupportSenderRole { customer, provider, user, staff, system }
class SupportThread { id, kind, disputeId, participants, status, lastMessageAt }
class SupportMessage { id, threadId, senderId, senderRole, senderName, body, createdAt, sendState }  // MessageSendState reused
// support_repository.dart
abstract class SupportRepository {
  String helpThreadIdFor(String uid);                                   // 'help_$uid'
  Stream<SupportThread?> watchThread(String threadId);
  Stream<List<SupportMessage>> watchMessages(String threadId, {int limit = 30});
  Future<String> send({String? threadId, required String text, required String clientId});   // → threadId; throws SupportError
}
class SupportError implements Exception { const SupportError(this.code); final String code; }
// support_providers.dart: supportRepositoryProvider, supportThreadProvider(threadId), supportMessagesProvider(threadId)

// lib/features/disputes/dispute_entry.dart  (entry API, also for #130)
sealed class DisputeSubject {
  const factory DisputeSubject.booking(String bookingId) = BookingDisputeSubject;
  const factory DisputeSubject.ticket({required String eventId, required String registrationId}) = TicketDisputeSubject;
}
class DisputeSubjectSummary { const DisputeSubjectSummary({required this.title, required this.subtitle, this.thumbUrl, this.badge}); }
/// Opens S18.01. Resolves to the new dispute id after a successful submit, null when closed.
Future<String?> showOpenDisputeSheet(BuildContext context, {required DisputeSubject subject,
  required DisputeSubjectSummary summary, required DateTime closesAt, DisputeOrigin origin = DisputeOrigin.booking});
/// Hours left (ceil), null when closed. Pure, used by S05.02/S11.04 to show the entry.
int? disputeHoursLeft(DateTime closesAt, DateTime now);
DateTime? bookingDisputeClosesAt(Booking b);          // status completed|reviewed, escrow held|partiallyRefunded, completedAt + 24 h
DateTime? ticketDisputeClosesAt(EventRegistration r); // paid, amount > 0, disputeId null, endsAt + 24 h
```

Routes: `/b/:id/dispute` (`BookingDetailScreen(openSheet: DetailSheet.dispute)`, `?from=delivery` → `DisputeOrigin.deliveryCheck`), `/disputes/:id` (`DisputeDetailScreen`, `ScreenCodes.disputeDetail`), `/help` (`HelpScreen`, `ScreenCodes.help`), `/help/chat` (`SupportChatScreen`, `ScreenCode(ScreenCodes.help, label: 'chat')`). New icons: `AppIcons.help = Symbols.help`, `AppIcons.supportAgent = Symbols.support_agent`.

### Strings (`app_vi.arb`, exact)

S18.01: `disputeSheetTitle` "Báo vấn đề"; `disputeSheetTitleDelivery` "Báo vấn đề với ảnh gốc"; `disputeWindowLeft` "Còn {hours} giờ để báo vấn đề. Tiền của buổi chụp được giữ tới khi có kết quả."; `disputeWindowLeftTicket` "Còn {hours} giờ để báo vấn đề. Tiền vé được giữ tới khi có kết quả."; `disputeWindowLeftDelivery` "Còn {hours} giờ để kiểm tra bộ ảnh gốc. Đợt thanh toán thứ hai được giữ tới khi có kết quả."; `disputeReasonTitle` "Vấn đề là gì?"; `disputeReasonNoShow` "Thợ không đến"; `disputeReasonNotAsAgreed` "Không đúng thoả thuận"; `disputeReasonPhotosMissing` "Thiếu ảnh"; `disputeReasonNotAsSample` "Khác ảnh mẫu"; `disputeReasonLinkBroken` "Link hỏng"; `disputeReasonEventNotHeld` "Sự kiện không diễn ra"; `disputeReasonNotAsDescribed` "Khác mô tả"; `disputeReasonOther` "Lý do khác"; `disputeDescriptionLabel` "Mô tả"; `disputeDescriptionHint` "Chuyện gì đã xảy ra? Càng cụ thể, hỗ trợ xử lý càng nhanh."; `disputeDescriptionTooShort` "Viết ít nhất 10 ký tự"; `disputeEvidenceTitle` "Ảnh bằng chứng · {count}/5"; `disputeEvidenceAdd` "Thêm ảnh"; `disputeEvidenceRemove` "Bỏ ảnh"; `disputeEvidenceNote` "Ảnh chỉ bạn, người bị khiếu nại và đội hỗ trợ xem được."; `disputeEvidenceFailed` "Một ảnh chưa tải lên được. Chạm để thử lại."; `disputeSubmit` "Gửi khiếu nại"; `disputeSent` "Đã gửi khiếu nại. Tiền được giữ tới khi có kết quả."; `disputeDiscardTitle` "Bỏ nội dung đang viết?"; `disputeDiscardConfirm` "Bỏ"; `disputeDiscardKeep` "Viết tiếp"; `disputeErrNotEligible` "Khoản này không còn mở khiếu nại được."; `disputeErrDeadline` "Đã quá thời hạn báo vấn đề."; `disputeErrConflict` "Đã có một khiếu nại đang mở cho khoản này."; `disputeErrGeneric` "Chưa gửi được. Kiểm tra kết nối rồi thử lại."
Entries: `disputeReportProblem` "Báo vấn đề · còn {hours} giờ"; `ticketReportProblem` "Báo vấn đề"; `disputeBannerOpen` "Đang khiếu nại"; `disputeBannerOpenBody` "Tiền được giữ tới khi có kết quả."; `disputeBannerResolved` "Khiếu nại đã có kết quả"; `disputeBannerView` "Xem khiếu nại".
S18.02: `disputeTitle` "Khiếu nại #{code}"; `disputeStatusOpen` "Đang xem xét"; `disputeStatusResolved` "Đã xử lý"; `disputeHeld` "Tiền đang giữ"; `disputeHeldNote` "Tạm dừng chuyển cho tới khi có kết quả"; `disputeOpenedAt` "Gửi lúc"; `disputeStepSent` "Đã gửi khiếu nại"; `disputeStepSentBody` "Mô tả và {count} ảnh bằng chứng"; `disputeStepReview` "Hỗ trợ đang xem xét"; `disputeStepReviewBody` "Hai bên trao đổi và gửi thêm bằng chứng ở mục Trao đổi"; `disputeStepOutcome` "Kết quả"; `disputeStepOutcomeBody` "Chuyển cho người nhận, hoàn cho bạn, hoặc chia"; `disputeDetailsTitle` "Mô tả & ảnh"; `disputeThreadTitle` "Trao đổi"; `disputeThreadHint` "Nhắn cho hỗ trợ…"; `disputeThreadClosed` "Khiếu nại đã đóng. Cần thêm hỗ trợ? Liên hệ ở mục Trợ giúp."; `disputeSenderSupport` "Hỗ trợ"; `disputeSenderProvider` "{name} · nhiếp ảnh gia"; `disputeSenderHost` "{name} · chủ sự kiện"; `disputeSenderCustomer` "{name} · khách"; `disputeResolvedToast` "Đã có kết quả · {when}"; `disputeOutcome` "Kết quả"; `disputeOutcomeRelease` "Chuyển tiền cho {name}"; `disputeOutcomeRefund` "Hoàn 100%"; `disputeOutcomeSplit` "Chia: hoàn {percent}%"; `disputeRefundToYou` "Hoàn cho bạn"; `disputeRefundToCustomer` "Hoàn cho khách"; `disputeReleaseTo` "Chuyển cho {name}"; `disputeReleaseToYou` "Chuyển cho bạn"; `disputeRefundWhere` "Về tài khoản hoặc ví đã thanh toán"; `disputeStaffNote` "Ghi chú của hỗ trợ: {note}"; `disputePlatformName` "ứng dụng"; `disputeNotFound` "Không tìm thấy khiếu nại"; `disputeNotFoundBody` "Khiếu nại này không tồn tại hoặc bạn không có quyền xem."; `supportSendFailed` "Chưa gửi được tin nhắn. Thử lại."; `supportRateLimited` "Bạn gửi hơi nhanh. Đợi vài phút rồi gửi tiếp."
S18.03 and chat: Task 8 lists them (FAQ). Settings: `settingsSupportSection` "Hỗ trợ"; `settingsHelp` "Trợ giúp"; `settingsHelpBody` "Câu hỏi thường gặp, liên hệ hỗ trợ".

## Review Focus

1. **Money released while disputed.** A disputed payment must survive `bookingClock` step 5 and the event completion (`releaseAfter` set) and never enter a payout. Pinned by Task 2 test `a disputed payment is not released by runBookingSweeps even after releaseAfter`.
2. **Split math on a partly refunded payment.** The percent applies to what is still held; the ledger invariant holds after every outcome; a 100% outcome on a partially refunded payment never refunds more than was paid. Pinned by Task 2 tests `split 40% of a partially refunded payment refunds 40% of the held rest` and `verifyPaymentLedgerInvariant holds after release, refund and split`.
3. **Privacy of evidence and threads.** A third user reads neither the dispute, nor the thread, nor an evidence file; a party can; a missing help thread reads as absent (not a permission error, or S18.03 crashes into its error state). Pinned by Task 3 rules tests and Task 5 test `watchThread of a missing help thread emits null`.
4. **Double tap and abandoned sheets.** Re-sending the same `disputeId` returns the same dispute; a second dispute on the subject is `conflict`; photos uploaded in a sheet the user closes are deleted. Pinned by Task 2 `openDispute is idempotent for the same id` and Task 6 `closing the sheet after uploads deletes them`.
5. **Mirrors survive other writes.** After a dispute, a booking transition (review, reschedule system write) must keep `disputeId`, and the S05.02 banner must stay. Pinned by Task 3 test `bookingToFirestore round-trips disputeId` and `registration mapping round-trips disputeId`.

## Chi phí Google

Unit prices from `docs/superpowers/specs/2026-10-07-google-cloud-costs.md`: Firestore $0.06/100K reads, $0.18/100K writes (nam5 upper bound, **chưa xác nhận** for Singapore); Functions free to 2M invocations then $0.40/M, Tier 2 $0.0000336/vCPU-s (180K vCPU-s free); Storage $0.020/GB-month; egress $0.12/GB (**giả định**). Volumes assumed: disputes 3% of bookings + 1 ticket dispute → 10/month at (b) 1,000 MAU (300 bookings), 100/month at (c) 10,000 MAU; 8 thread messages per dispute; help chats started by 3% of MAU with 5 messages each.

| Action | Reads | Writes | Notes |
|---|---|---|---|
| Show "Báo vấn đề" on S05.02 / S11.04 | 0 | 0 | from the booking / registration already loaded |
| Submit S18.01 (`openDispute`) | ~6 (dispute, subject, payment query, refunds, user name) | 6 (dispute, payment, subject mirror, thread, 2 messages) | + ≤ 5 Storage uploads |
| `onDisputeWrite` notify | ~3 per recipient | ~2 per recipient | prefs, user, inbox row |
| Open S18.02 | 1 + 1 + ≤ 30 | 0 | listeners (live thread while open), messages `limit(30)` |
| Send a thread message | 3 | 2 | + trigger notify ~3 reads / 2 writes per other party |
| Open S18.03 | ≤ 10 (`mine`, `get`, `limit(10)`, min 1) | 0 | FAQ is in the app |
| Open support chat | 1 + ≤ 30 | 0 | listener while open |
| `resolveDispute` | ~5 | ~6 (+ refund save) | |

New functions: 3 callables + 2 triggers. Calls/month: (b) `openDispute` 10, `resolveDispute` 10, `sendSupportMessage` 80 + 150, triggers ≈ 260 → ~510; (c) ~5,100. All far inside the free 2M; CPU ~0.2 vCPU-s each → < 1,100 vCPU-s. No scheduled job (no new Cloud Scheduler cost). Storage path `disputeEvidence/`: ~3 photos × 0.45 MB per dispute (`ImagePurpose.document`: 2048 px q85, ≤ 3 MiB by rule, no thumbnail: viewed rarely, at most 5 per dispute) → 13.5 MB/month at (b), 135 MB/month at (c), kept (Needs the owner 3) → 1.6 GB after a year at (c) = $0.03/month; egress ~5 views each → 70 MB (b), 675 MB (c) → $0.01 / $0.08. No paid API (no Maps, SMS, Vision).

Reads/month: (b) ≈ 7,000 ($0.004), (c) ≈ 70,000 ($0.04); writes (b) ≈ 1,000, (c) ≈ 10,000 ($0.02).

**Conclusion:** adds about **$0.02/month at (b)** and **$0.15/month at (c)**; well under $5, no mitigation needed. Limits that keep it there: `limit(30)` thread pages, `get` for S18.03, rate limit on support messages, no thumbnails for rarely viewed evidence.

## Tasks

### Task 1: Mock frames, screen codes and screen spec

**Files:**
- Modify: `docs/design/ui-mock.html` (new section before `<h2 id="S24">`, after S17; code table row cells; progress table; S09.02 caption), `docs/superpowers/specs/2026-10-01-remaining-screens.md` (§2 S18 rows, §3i.1 one paragraph), `docs/superpowers/specs/screens/README.md` (index row)
- Create: `docs/superpowers/specs/screens/disputes-help.md`
- Check only: `app_flutter/lib/core/screen_codes.dart` (S18.01–S18.03 exist; no change unless a name differs)

**Interfaces:** Produces frame ids `S18.01`, `S18.01-delivery`, `S18.02`, `S18.02-resolved`, `S18.03`, `S18.03-chat`, `S05.02-problem`, `S05.02-disputed` that later tasks cite.

- [ ] **Step 1:** Insert the section. Header and intro, verbatim:
  ```html
  <h2 id="S18">S18 · Khiếu nại & hỗ trợ</h2>
  <p>Khách báo vấn đề trong cửa sổ khiếu nại của buổi chụp hoặc vé; tiền của khoản đó dừng lại cho tới khi đội hỗ trợ quyết định chuyển, hoàn hoặc chia. Màn liên quan: <a href="#S05.06-approved" style="color:var(--accent)">S05.06 · Báo vấn đề với ảnh gốc</a>, <a href="#S06.05" style="color:var(--accent)">S06.05 · Đang khiếu nại</a>.</p>
  <div class="rail">
  ```
  Then the frames below (each followed by its `.cap`), and `</div>` closing the rail. Use the classes exactly as written; every frame starts with `<div class="sb"><span>9:41</span><span>●●● ▮</span></div>`.
- [ ] **Step 2: `S05.02-problem`** (`data-code="S05.02"`). Body: `.bar` (back · "Buổi chụp #A1F3" · `more_horiz`); `.card` (`.th ph p3`, `<b>Minh Trí · Chân dung 2 giờ</b>`, meta "T7 12/10 · 15:30–17:30", `<br>` meta "Bến Bạch Đằng", `badge b-done` "Hoàn thành"); three `.tl` rows: done "Buổi chụp" / "T7 12/10 · 15:30", done "Hoàn thành" / "Hôm qua 17:45", now "Đánh giá & chia sẻ ảnh"; `.row` with `btn out sm` "Nhắn tin" and `btn pri sm` "Đánh giá"; `<div class="btn txt sm" style="color:var(--bad)">Báo vấn đề · còn 18 giờ</div>`. Cap: `<span class="n new">Mới</span><span class="n">S05.02 · Báo vấn đề</span><b>Nút chỉ hiện trong cửa sổ khiếu nại</b><span>Khách thấy "Báo vấn đề · còn {h} giờ" (chữ đỏ) trong 24 giờ sau khi buổi chụp hoàn thành, khi tiền còn đang giữ. Chạm → S18.01. Hết giờ thì nút biến mất; S18.03 giải thích thời hạn.</span>`
- [ ] **Step 3: `S18.01`** — sheet over the S05.02-problem body (bar + card, then `<div class="dim"></div>`):
  ```html
  <div class="sheet">
    <div class="grab"></div>
    <div class="row" style="justify-content:space-between"><div class="h3">Báo vấn đề</div><div class="ic" role="button" tabindex="0" aria-label="Đóng"><span class="ms">close</span></div></div>
    <div class="esc"><span class="ms">schedule</span><span>Còn 18 giờ để báo vấn đề. Tiền của buổi chụp được giữ tới khi có kết quả.</span></div>
    <b style="font-size:13px">Vấn đề là gì?</b>
    <div class="chips wrap"><span class="chip">Thợ không đến</span><span class="chip">Không đúng thoả thuận</span><span class="chip on">Thiếu ảnh</span><span class="chip">Khác ảnh mẫu</span><span class="chip">Link hỏng</span><span class="chip">Lý do khác</span></div>
    <div class="field foc" style="min-height:64px"><small>Mô tả</small>Gói 40 ảnh nhưng mình chỉ nhận được 28 ảnh, thiếu phần chụp ở bến.</div>
    <div class="meta x tn" style="text-align:right;margin-top:-6px">62/1000</div>
    <b style="font-size:12.5px">Ảnh bằng chứng · 2/5</b>
    <div class="grid3"><div class="ph p5" role="img" aria-label="Ảnh bằng chứng 1"></div><div class="ph p2" role="img" aria-label="Ảnh bằng chứng 2"></div><div class="ph add" role="button" tabindex="0" aria-label="Thêm ảnh"><span class="ms">add</span></div></div>
    <div class="lockn"><span class="ms">lock</span><span>Ảnh chỉ bạn, người bị khiếu nại và đội hỗ trợ xem được.</span></div>
    <div class="btn pri">Gửi khiếu nại</div>
  </div>
  ```
  Cap: `<span class="n new">Mới</span><span class="n">S18.01 · Mở khiếu nại (sheet)</span><b>Một lý do, vài dòng, vài ảnh</b><span>Mở từ S05.02 ("Báo vấn đề"), từ vé đã qua ở S11.04 và từ S05.06 ("Báo vấn đề với ảnh gốc"). Lý do là chip chọn một: buổi chụp có Thợ không đến, Không đúng thoả thuận, Thiếu ảnh, Khác ảnh mẫu, Link hỏng, Lý do khác; vé có Sự kiện không diễn ra, Khác mô tả, Lý do khác. Mô tả bắt buộc (10–1000 ký tự), tối đa 5 ảnh bằng chứng, lưu riêng tư. Gửi xong mở S18.02; tiền của khoản đó dừng chuyển ngay. Vuốt xuống khi đã nhập thì hỏi "Bỏ nội dung đang viết?".</span>`
- [ ] **Step 4: `S18.01-delivery`** (`data-code="S18.01"`) — background: `.bar` (back · "Bàn giao · đã đồng ý" · `more_horiz`) and the S05.06-approved `.toast` "Bạn đã đồng ý ảnh lúc 10:12 15/10. Link bộ ảnh gốc đã mở."; sheet: h3 "Báo vấn đề với ảnh gốc" + close; `.esc` (`schedule`) "Còn 47 giờ để kiểm tra bộ ảnh gốc. Đợt thanh toán thứ hai được giữ tới khi có kết quả."; "Vấn đề là gì?"; chips "Thiếu ảnh" (on), "Khác ảnh mẫu", "Link hỏng", "Lý do khác"; `<div class="field" style="min-height:64px"><small>Mô tả</small><span style="color:var(--ink-3)">Chuyện gì đã xảy ra? Càng cụ thể, hỗ trợ xử lý càng nhanh.</span></div>`; "Ảnh bằng chứng · 0/5" with only the `ph add` tile in the `grid3`; the same `.lockn`; `btn pri` "Gửi khiếu nại". Cap: `<span class="n new">Mới</span><span class="n">S18.01 · Báo vấn đề với ảnh gốc</span><b>Lý do điền sẵn cho 48 giờ kiểm tra</b><span>Mở từ nút chữ đỏ ở S05.06 sau khi đồng ý ảnh (bàn giao, #130). Chỉ bốn lý do; cửa sổ là 48 giờ kiểm tra; đợt 2 tiếp tục được giữ.</span>`
- [ ] **Step 5: `S18.02`** (customer, open). Body (`style="gap:10px"`): `.bar` (back · "Khiếu nại #K7Q2" · `<div class="ic" style="opacity:0"></div>`); `.card` (`<div class="th ph p3" style="width:48px;height:48px"></div>`, b "Minh Trí · Chân dung 2 giờ", meta "T7 12/10 · Thiếu ảnh", `badge b-pen` "Đang xem xét"); `.kv` with `<div><small>Tiền đang giữ</small><b class="tn">1.500.000₫<span class="meta">Tạm dừng chuyển cho tới khi có kết quả</span></b></div>` and `<div><small>Gửi lúc</small><b class="tn">10:12 14/10</b></div>`; a column of `.tl`: done "Đã gửi khiếu nại" / "Mô tả và 2 ảnh bằng chứng", now "Hỗ trợ đang xem xét" / "Hai bên trao đổi và gửi thêm bằng chứng ở mục Trao đổi", plain "Kết quả" / "Chuyển cho người nhận, hoàn cho bạn, hoặc chia"; `.sec` `<b>Mô tả & ảnh</b>`; meta (ink) "Gói 40 ảnh nhưng mình chỉ nhận được 28 ảnh, thiếu phần chụp ở bến."; `.grid3` with two `ph` (p5, p2); `.sec` `<b>Trao đổi</b>`; messages: `<div><div class="sn">Hỗ trợ</div><div class="bub you">Chào chị, em đã nhận khiếu nại. Anh Minh Trí vui lòng gửi giải trình trong 24 giờ.</div></div>`, `<div><div class="sn">Minh Trí · nhiếp ảnh gia</div><div class="bub you">Em đã gửi bù 12 ảnh còn thiếu vào link cũ rồi ạ.</div></div>`, `<div class="bub me">Mình mở link vẫn thấy 28 ảnh.</div>`; composer row: `<div class="row" style="padding-bottom:8px"><div class="search" style="flex:1;height:40px;border-radius:999px">Nhắn cho hỗ trợ…</div><div class="ic" role="button" tabindex="0" aria-label="Gửi" style="background:var(--cta);color:#fff"><span class="ms">arrow_forward</span></div></div>`. Cap: `<span class="n new">Mới</span><span class="n">S18.02 · Chi tiết khiếu nại</span><b>Tiền đang ở đâu, việc đang tới đâu</b><span><code>/disputes/:id</code>, cho khách và người nhận tiền (thợ ảnh hoặc chủ sự kiện). Thứ tự: khoản bị khiếu nại + trạng thái, tiền đang giữ, ba bước, mô tả và ảnh (chạm mở toàn màn), rồi Trao đổi: một cuộc trò chuyện chung của khách, người nhận tiền và đội hỗ trợ; tin của người nhận tiền là giải trình. Người nhận tiền thấy cùng màn với chữ "Hoàn cho khách" / "Chuyển cho bạn". Không mở thêm kênh liên hệ ngoài app.</span>`
- [ ] **Step 6: `S18.02-resolved`** (`data-code="S18.02"`): `.bar` as above; `.toast` (`<i><span class="ms">check</span></i>`) "Đã có kết quả · 16:40 15/10"; `.card` as above but `badge b-done` "Đã xử lý"; `.kv` rows: `<small>Kết quả</small><b>Chia: hoàn 40%</b>`, `<small>Hoàn cho bạn</small><b class="tn">600.000₫<span class="meta">Về tài khoản hoặc ví đã thanh toán</span></b>`, `<small>Chuyển cho Minh Trí</small><b class="tn">900.000₫</b>`; `.esc` (`info`) "Ghi chú của hỗ trợ: Thợ ảnh đã giao bù đủ 40 ảnh nhưng trễ 3 ngày. Hai bên đồng ý hoàn 40%."; `.sec` `<b>Trao đổi</b>`; meta x "Khiếu nại đã đóng. Cần thêm hỗ trợ? Liên hệ ở mục Trợ giúp."; `.foot` with `btn out` "Liên hệ hỗ trợ". Cap: `<span class="n new">Mới</span><span class="n">S18.02 · Đã có kết quả</span><b>Kết quả bằng số tiền, không chỉ bằng chữ</b><span>Ba kết quả: chuyển tiền cho người nhận, hoàn 100%, hoặc chia theo phần trăm của số đang giữ. Ghi chú của hỗ trợ luôn hiện. Trao đổi chỉ còn để đọc; "Liên hệ hỗ trợ" mở chat hỗ trợ (S18.03).</span>`
- [ ] **Step 7: `S05.02-disputed`** (`data-code="S05.02"`): S05.02-problem's bar and card; below the card `<div class="esc" role="button" tabindex="0"><span class="ms">flag</span><span class="grow"><b>Đang khiếu nại</b><br>Tiền được giữ tới khi có kết quả.</span><span class="tlink" style="padding:0">Xem khiếu nại</span></div>`; then the three `.tl` rows of Step 2; `.row` "Nhắn tin" (`btn out sm`) only. Cap: `<span class="n new">Mới</span><span class="n">S05.02 · Đang khiếu nại</span><b>Cả hai bên thấy khoản đang bị giữ</b><span>Khi buổi chụp có khiếu nại, khách và thợ ảnh thấy dải này ở S05.02 → S18.02. Có kết quả thì dải thành "Khiếu nại đã có kết quả". Nút "Báo vấn đề" không hiện nữa.</span>`
- [ ] **Step 8: `S18.03`**: `.body` (`gap:10px`): `.bar` (back · "Trợ giúp" · invisible ic); `.sec` `<b>Khiếu nại của bạn</b>`; `<div class="card" role="button" tabindex="0" style="padding:8px 10px"><div class="ic" style="background:var(--field);color:var(--ink-2)"><span class="ms">flag</span></div><div class="t"><b>Khiếu nại #K7Q2 · Minh Trí</b><span class="meta">Đang xem xét · 14/10</span></div><span class="ms chev">chevron_right</span></div>`; `.sec` `<b>Câu hỏi thường gặp</b>`; `.chips` "Thanh toán" (on), "Huỷ & hoàn tiền", "Bàn giao ảnh", "Khiếu nại", "Liên hệ"; a `.card` (`flex-direction:column;align-items:stretch;padding:2px 12px;gap:0`) with: `<div class="irow2 x" aria-expanded="true"><div class="grow"><b>Vì sao phải trả trước 100%?</b></div><span class="ms" style="color:var(--ink-3)">expand_less</span><div class="brk"><span class="meta">Tiền không đến tay thợ ngay. Ứng dụng giữ tiền và chỉ chuyển cho thợ theo 2 đợt: sau buổi chụp, và sau khi bạn đồng ý ảnh rồi kiểm tra bộ ảnh gốc trong 48 giờ. Có lỗi thì bạn được hoàn qua ứng dụng.</span></div></div>` and two collapsed rows (`expand_more`) "Tiền của tôi được giữ ở đâu?", "Chuyển khoản QR sai số tiền thì sao?". `.foot`: `<div class="btn pri"><span class="ms" style="font-size:18px">support_agent</span>Liên hệ hỗ trợ</div>`. Cap: `<span class="n new">Mới</span><span class="n">S18.03 · Trợ giúp</span><b>Tự tìm câu trả lời trước, hỏi người khi cần</b><span><code>/help</code>, mở từ Cài đặt (nhóm Hỗ trợ) và từ S18.02. "Khiếu nại của bạn" chỉ hiện khi có. Câu hỏi thường gặp theo chủ đề (Thanh toán, Huỷ & hoàn tiền, Bàn giao ảnh, Khiếu nại, Liên hệ, Đánh giá, Dành cho thợ ảnh), chạm để mở câu trả lời. "Liên hệ hỗ trợ" mở chat với hộp thư hỗ trợ. Dòng "Email hỗ trợ: …" dưới nút chỉ hiện khi bản build có địa chỉ (<code>SUPPORT_EMAIL</code>).</span>`
- [ ] **Step 9: `S18.03-chat`** (`data-code="S18.03"`): `.bar` (back · "Hỗ trợ" · invisible ic); `.esc` (`lock`) "Chỉ bạn và đội hỗ trợ xem được cuộc trò chuyện này. Đừng gửi mật khẩu hay mã OTP."; messages column (`flex:1`): `<div class="bub me">Mình muốn đổi số điện thoại nhận thông báo thì làm ở đâu?</div>`, `<div><div class="sn">Hỗ trợ</div><div class="bub you">Chào bạn, vào Cài đặt → Số điện thoại để đổi nhé. Số mới dùng ngay cho lần đặt lịch sau.</div></div>`; composer row as S18.02 with "Nhắn cho hỗ trợ…". Cap: `<span class="n new">Mới</span><span class="n">S18.03 · Chat hỗ trợ</span><b>Một hộp thư, trả lời ngay trong app</b><span><code>/help/chat</code>. Chưa có tin nào thì hiện "Bạn cần giúp gì? Nhắn cho đội hỗ trợ, chúng tôi trả lời tại đây và báo cho bạn khi có tin mới." Hỗ trợ trả lời thì có thông báo. Chỉ chữ, tối đa 1000 ký tự; gửi quá nhanh thì báo đợi vài phút.</span>`
- [ ] **Step 10:** Code table (the single long line under "Mã màn hình"): S18.01, S18.02, S18.03 cells "Chưa có mock" → "Có". Progress table: add `<tr><td>Khiếu nại & hỗ trợ</td><td>S18.01–S18.03, S05.02 (Báo vấn đề, đang khiếu nại)</td><td>Có mock, có plan (#142)</td></tr>`. S09.02 caption: append "Nhóm <b>Hỗ trợ</b>: Trợ giúp (S18.03)." This line is also edited by #143/#144: on a rebase conflict re-apply only the S18 cells.
- [ ] **Step 11:** Spec §2: S18.01 route `/b/:id/dispute` (sheet trên S05.02; `?from=delivery` từ S05.06) · sheet trên S11.04 (vé); S18.03 route `/help`, `/help/chat`; the three status cells "⬜ có mock, có plan (#142)". §3i.1: add one paragraph "Đã chốt khi viết plan #142 (2026-10-07)" summarising Decisions 2, 7, 8, 9 in Vietnamese. Create `screens/disputes-help.md` with the README template for S18.01, S18.02, S18.03 (+ chat), copying the strings of this plan's Contract and Task 8, and add its index row to `screens/README.md`.
- [ ] **Step 12:** Open the mock with `#S18.01` and check every frame renders (no broken tags: `python3 -c "import html.parser,sys; p=html.parser.HTMLParser(); p.feed(open('docs/design/ui-mock.html').read())"` runs clean; count of `<div` equals `</div>` inside the new section).
- [ ] **Step 13: Commit** `docs(mock): S18 disputes and help frames, screen spec [#142]`.

### Task 2: Domain — disputes, outcomes, support threads, notifications

**Files:**
- Create: `packages/domain/src/dispute.ts`, `dispute_ports.ts`, `dispute_use_cases.ts`, `support_thread.ts`, `support_use_cases.ts`, `dispute_notifications.ts`, `memory_dispute_store.ts`; tests `packages/domain/test/dispute.test.ts`, `dispute_use_cases.test.ts`, `support_use_cases.test.ts`, `dispute_notifications.test.ts`, `test/support/dispute_world.ts`
- Modify: `escrow.ts` (`Payment.dispute` shape, `applyRefundToPayment` `amount?`), `booking.ts` (`Booking.disputeId?: string | null`), `notification.ts`, `notification_render.ts`, `booking_policy.ts` (remove `MIN/MAX_DISPUTE_REASON_LENGTH`), `index.ts`, `test/notification_render.test.ts`, `test/escrow.test.ts`, `test/booking_sweeps.test.ts`
- Delete: `open_dispute.ts`, `test/open_dispute_reason.test.ts`

**Interfaces:** Produces everything under "Domain" in the Contract. Consumes `applyRefundToPayment`, `releaseEscrowPayment`, `disputeEscrowPayment`, `verifyPaymentLedgerInvariant`, `notify`, `graphemeCount`, `truncateGraphemes`, `formatVnd`, `formatDayShortVi`, `isId`.

- [ ] **Step 1:** Contract check (domain bullets above); ledger differences.
- [ ] **Step 2: Failing tests.** `dispute.test.ts`: `parseOpenDisputeInput accepts a booking dispute with 0–5 evidence paths`; `refuses a reason that does not belong to the subject` (ticket + `no_show` → invalid_argument); `refuses a description under 10 or over 1000 graphemes after trim`; `refuses 6 evidence paths and a path under another uid or another dispute id`; `disputeWindow: completed booking closes 24 h after completedAt`; `reviewed booking is eligible`; `upcoming booking is not_eligible`; `at completedAt + 24 h exactly → deadline_passed`; `paid ticket opens at endAt and closes 24 h later; before endAt → not_eligible`; `free ticket → not_eligible`; `outcomeAmounts: release 0/held, refund held/0, split 40% of 1 500 000 → 600 000 / 900 000, split 33% of 1 000 001 floors the refund`; `split 0 or 100 or 12.5 → invalid_argument`.
  `dispute_use_cases.test.ts` (`createDisputeWorld()`): `openDispute freezes the held payment, links the booking and opens the thread with a system message and the description`; `stores prevEscrowStatus partially_refunded`; `openDispute is idempotent for the same id` (same result, one thread, no second message); `a second dispute on the same booking → conflict`; `another customer → permission_denied`; `a booking whose payment was already released → not_eligible`; `ticket dispute freezes the ticket payment and sets registration.disputeId; platform event → parties is the customer only`; `resolveDispute release: payment released, booking escrowStatus released, outcome stored with decidedBy, thread closed with a system message`; `refund: payment refunded, one refund row pending, ledger refund_issued`; `split 40% of a partially refunded payment refunds 40% of the held rest`; `verifyPaymentLedgerInvariant holds after release, refund and split`; `resolving twice → conflict`; `note under 5 characters → invalid_argument`; `dispatchDisputeRefund marks the refund done, or failed+manual when the gateway fails`.
  `booking_sweeps.test.ts`: `a disputed payment is not released by runBookingSweeps even after releaseAfter`.
  `support_use_cases.test.ts`: `first help message creates help_{uid} with the sender as participant and awaitingStaff true`; `same clientId twice writes one message`; `a dispute party can write while open, its role is customer or provider`; `a non-party → permission_denied`; `after resolution → not_eligible`; `11th message in 10 minutes → limit_exceeded, the window restarts after 10 minutes`; `staffReply writes senderName Hỗ trợ, role staff, awaitingStaff false`; `text over 1000 graphemes or blank → invalid_argument`.
  `dispute_notifications.test.ts`: `open notifies the provider only, not a platform payee`; `resolve notifies every party with the outcome copy`; `staff message notifies all participants with support_reply`; `a provider message notifies the customer with dispute_message grouped by dispute`; `system messages notify nobody`. `notification_render.test.ts`: one case per new type with the exact Contract copy.
- [ ] **Step 3:** Run `cd packages/domain && npm test` — new tests fail.
- [ ] **Step 4: Implement.** The resolve transaction is the part to get right:
  ```ts
  export async function resolveDispute(deps: DisputeDeps, staffId: string, raw: unknown) {
    const input = parseResolveInput(raw);                     // disputeId, kind, refundPercent?, note (5–500)
    const now = deps.clock.now();
    const pre = await deps.store.runTransaction((tx) => tx.getDispute(input.disputeId));
    if (!pre) throw new DomainError('not_found');
    const refundsSoFar = (await deps.store.getRefundsForPayment(pre.paymentId)).reduce((s, r) => s + r.amount, 0);
    return deps.store.runTransaction(async (tx) => {
      const d = await tx.getDispute(input.disputeId);
      const p = d && (await tx.getPayment(d.paymentId));
      const subject = d && (await tx.getSubject(d.subjectType, d.subjectId, d.eventId));
      if (!d || !p || !subject) throw new DomainError('not_found');
      if (d.status !== 'open' || p.escrowStatus !== 'disputed') throw new DomainError('conflict');
      const held = p.amount - refundsSoFar;
      const a = outcomeAmounts(held, input.kind, input.refundPercent);
      let pay: Payment = { ...p, escrowStatus: p.dispute?.prevEscrowStatus ?? 'held', updatedAt: now.toISOString() };
      let refund: Refund | null = null;
      if (a.refundAmount > 0) {
        const r = applyRefundToPayment({ payment: pay, refundId: deps.ids.newId(), percent: a.refundPercent,
          amount: a.refundAmount, ledgerEntryId: deps.ids.newId(), reason: `dispute:${d.id}`, now });
        pay = r.payment; refund = r.refund; tx.addRefund(r.refund); tx.addLedgerEntry(r.ledgerEntry);
      }
      if (a.releaseAmount > 0) {
        const r = releaseEscrowPayment({ payment: pay, refundAmount: refundsSoFar + a.refundAmount,
          ledgerEntryId: deps.ids.newId(), now });
        pay = r.payment; tx.addLedgerEntry(r.ledgerEntry);
      }
      tx.setPayment(pay);
      tx.linkSubject(subject, { disputeId: d.id, escrowStatus: pay.escrowStatus });
      // … dispute resolved + outcome (decidedBy = staffId), thread closed, system message; read everything before the first write.
    });
  }
  ```
  `openDispute`: parse → read dispute by id (idempotent return) → subject → `permission_denied` unless `customerId === caller` → `disputeWindow` → an open `subject.disputeId` dispute → `conflict` → `findSubjectPayment` must be `held|partially_refunded` (else `not_eligible`) → `amountHeld = amount − refunds` (refunds read before the transaction) → writes. `MemoryDisputeStore` refuses reads after writes inside one transaction. Delete `open_dispute.ts` and its test; export the new modules from `index.ts`.
- [ ] **Step 5:** `npm test && npm run lint` green (including `purity.test.ts`).
- [ ] **Step 6: Commit** `feat(domain): disputes with escrow freeze and outcomes, support threads [#142]`.

### Task 3: Functions — adapters, callables, rules, Storage, indexes, seed

**Files:**
- Create: `app_flutter/firebase/functions/src/infra/dispute_firestore.ts` (`FirestoreDisputeStore implements DisputeStore, SupportStore`, `FirestoreDisplayNames`), `src/infra/live_dispute.ts` (`liveDisputeDeps()`, `liveSupportDeps()`), `src/callables/dispute.ts` (`handleOpenDispute`, `handleResolveDispute`), `src/callables/support.ts` (`handleSendSupportMessage`); tests `test/unit/dispute_callables.test.ts`, `support_callables.test.ts`, `dispute_firestore.test.ts`; integration `test/integration/dispute.test.ts` (written, not run)
- Modify: `src/index.ts` (re-point `openDispute`; export `resolveDispute`, `sendSupportMessage`), `src/callables/booking.ts` (drop `handleOpenDispute` and its import), `src/infra/booking_firestore.ts` (`disputeId` both ways; payment `dispute.disputeId/prevEscrowStatus`), `src/infra/event_firestore.ts` (registration `disputeId` both ways), `seed/fixtures.ts`, `seed/README.md`, `test/unit/booking_callables.test.ts` (remove openDispute cases), `test/unit/booking_firestore.test.ts`, `test/unit/event_firestore.test.ts`, `test/unit/seed_fixtures.test.ts`; `app_flutter/firebase/firestore.rules`, `storage.rules`, `firestore.indexes.json`, `rules-test/rules.test.mjs`

**Interfaces:** Consumes the domain use cases (Task 2). Produces the callables of the Contract. `liveDisputeDeps()` = `{store: new FirestoreDisputeStore(db()), gateway: getSharedFakeGateway(), names: new FirestoreDisplayNames(db()), clock, ids: {newId: newUlid}}`. Staff check in `handleResolveDispute`: `request.auth?.token?.staffRole === 'admin'` else `permission_denied` (award pattern). After the resolve transaction the handler calls `dispatchDisputeRefund` when a refund was created and logs `dispute_resolved` with the dispute id only.

- [ ] **Step 1:** Contract check (Functions, rules bullets); ledger differences.
- [ ] **Step 2: Failing tests.** `dispute_callables.test.ts`: `openDispute without auth → unauthenticated`; `maps not_eligible, deadline_passed and conflict to failed-precondition/failed-precondition/aborted with details.code`; `returns {disputeId}`; `resolveDispute by a user without the admin claim → permission-denied`; `resolveDispute by admin returns the amounts and dispatches the refund once`. `support_callables.test.ts`: `sendSupportMessage without threadId writes to help_{uid}`; `limit_exceeded → resource-exhausted`. `dispute_firestore.test.ts`: `dispute document round-trips (Timestamps ↔ ISO, outcome null and set)`; `support message mapping keeps senderRole and senderName`; `findSubjectPayment for a booking picks the held payment`. `booking_firestore.test.ts`: `bookingToFirestore round-trips disputeId` and `payment dispute keeps disputeId and prevEscrowStatus`. `event_firestore.test.ts`: `registration mapping round-trips disputeId`. `seed_fixtures.test.ts`: `seed-dispute-lan-an is open on seed-booking-disputed with a thread`; `seed-booking-completed-window is completed 2 hours before seeding with a held payment`; `the past paid ticket ended 3 hours before seeding with a held payment`.
  Rules tests (written, not run): `a party reads its dispute`; `a third user cannot get or list a dispute`; `nobody writes disputes or support threads from the client`; `a user gets their missing help thread (no error)`; `a user cannot get another user's help thread`; `a party reads dispute thread messages, a third user cannot`. Storage rules tests: `owner uploads a JPEG under their uid, not another's`; `PNG or a JPEG over 3 MiB is refused` (`jpegUpTo`); `overwrite refused`; `a party reads evidence, a third user cannot`; `owner deletes evidence only while no dispute document exists`.
  Integration (written, not run): `openDispute then bookingClock leaves the payment disputed; resolveDispute split releases and refunds on the fake gateway`.
- [ ] **Step 3:** `cd app_flutter/firebase/functions && npm test` — the new unit tests fail.
- [ ] **Step 4: Implement** adapters (transaction: all reads first; `findSubjectPayment` for bookings = `payments where subjectId == bookingId` read inside the transaction with `tx.get(query)`), callables, rules, Storage rule and the three indexes (Contract). Seed per Decision 17 (compute the seed dispute with the same domain helpers, not by hand), README rows for the three new seed items and a "Staff CLI for disputes and support" note pointing to Task 4.
- [ ] **Step 5:** `npm test && npm run build` (functions) and `cd packages/domain && npm test` green. Ledger: rules/storage/integration tests written, not run.
- [ ] **Step 6: Commit** `feat(functions): openDispute, resolveDispute and support messages with rules and seed [#142]`.

### Task 4: Functions — notification triggers and staff CLIs

**Files:**
- Create: `src/triggers/dispute_write.ts` (`handleDisputeWrite(before, after, deps: NotifyDeps)`), `src/triggers/support_message_created.ts` (`handleSupportMessageCreated(threadId, messageData, deps)`), `tools/disputes.ts`, `tools/support.ts`; tests `test/unit/dispute_triggers.test.ts`, `disputes_cli.test.ts`, `support_cli.test.ts`
- Modify: `src/index.ts` (`onDisputeWrite`, `onSupportMessageCreated`), `package.json` (`"disputes": "tsx tools/disputes.ts"`, `"support": "tsx tools/support.ts"`), `seed/README.md` (CLI section)

**Interfaces:** Consumes `notifyDisputeChange`, `notifySupportMessage`, `resolveDispute`, `staffReply`, `dispatchDisputeRefund`, `liveNotifyDeps()`, `liveDisputeDeps()`, `liveSupportDeps()`. CLI shape copies `tools/awards.ts`: exported `parseArgs(argv)`, `HELP`, a `main()` guarded by `fileURLToPath(import.meta.url) === process.argv[1]`; `--actor` verified with Admin Auth `getUser(actor).customClaims.staffRole` (`admin` for disputes; `admin|sales` for support).

- [ ] **Step 1:** Contract check (`tools/awards.ts`, `award_cli.test.ts`, trigger exports in `index.ts`).
- [ ] **Step 2: Failing tests.** `dispute_triggers.test.ts`: `created open dispute → one dispute_opened to the provider`; `open → resolved → dispute_resolved to both parties`; `a retry of the same event writes no second row (dedupe)`; `a deleted document notifies nobody`; `support_reply for a staff message, dispute_message for a party message, nothing for system`. `disputes_cli.test.ts`: `parseArgs list/show/resolve release|refund|split`; `split needs 1–99`; `resolve needs a note and --actor`; `--help prints HELP`. `support_cli.test.ts`: `parseArgs list/show/reply`; `reply needs text and --actor`.
- [ ] **Step 3:** Run; they fail.
- [ ] **Step 4: Implement.** `list` prints id, created date, subject title, amount held, status (`listByStatus`); `show` prints the dispute, evidence paths and the last 30 thread messages; `resolve` runs `resolveDispute` then `dispatchDisputeRefund`; `support list` prints threads awaiting staff (`listAwaitingStaff(50)`); `reply` runs `staffReply` with a fresh ULID clientId.
- [ ] **Step 5:** `npm test && npm run build` green.
- [ ] **Step 6: Commit** `feat(functions): dispute and support notifications, staff CLIs for disputes and support [#142]`.

### Task 5: App data — support email, disputes, support threads, notification visuals

**Files:**
- Create: `app_flutter/lib/core/app_config.dart`; `lib/data/disputes/dispute.dart`, `dispute_repository.dart`, `firestore_dispute_repository.dart`, `dispute_providers.dart`; `lib/data/support/support_thread.dart`, `support_repository.dart`, `firestore_support_repository.dart`, `support_providers.dart`; `test/support/fake_dispute_repository.dart`, `fake_support_repository.dart`, `dispute_world.dart`; tests `test/core/app_config_test.dart`, `test/data/disputes/dispute_mapping_test.dart`, `test/data/support/support_mapping_test.dart`
- Modify: `lib/core/core.dart` (export), `lib/features/events/event_links.dart` (remove the support email pair), `lib/features/events/event_info_tab.dart` (use `supportEmail` / `supportEmailUri()`), `test/features/events/event_links_test.dart` (move its email cases to `app_config_test.dart`), `lib/data/booking/booking.dart` (+ `disputeId`), `firestore_booking_repository.dart` (map `disputeId`; remove `openDispute`), `booking_repository.dart` (remove `openDispute`), `booking_rules.dart` (remove `canCustomerDispute` and `disputeWindowHours`; their tests go), `test/support/fake_booking_repository.dart`, `lib/data/events/event_registration.dart` (+ `disputeId`), `firestore_event_mapping.dart`, `lib/core/theme/app_icons.dart` (`help`, `supportAgent`), `lib/features/notifications/notification_visuals.dart`, its test

**Interfaces:** Produces the Dart contract (`app_config.dart`, `lib/data/disputes/*`, `lib/data/support/*`). Notification visuals: `dispute_opened` → (`AppIcons.flag`, action); `dispute_resolved` → (`AppIcons.payment`, success); `dispute_message` → (`AppIcons.chat`, neutral); `support_reply` → (`AppIcons.supportAgent`, neutral). The notification files are append-only shared files (S17 plan `2026-10-07-s17-notifications.md`, Global Constraints): on a merge conflict keep both sides; if that plan's `notification_targets.dart` exists, add the four types there too (`/disputes/{id}`, `/help/chat`). Callable errors map like `callEventFunction`: `details.code` → `DisputeError(code)` / `SupportError(code)`, `unavailable|deadline-exceeded` → `'network'`.

- [ ] **Step 1:** Contract check (app data bullets); ledger differences.
- [ ] **Step 2: Failing tests:** `supportEmail is null when SUPPORT_EMAIL is empty; supportEmailUri builds mailto`; `Dispute.fromFirestore maps status, outcome and Timestamps; unknown reason → other`; `disputeCode takes the last 4 characters upper-cased`; `DisputeReason.offeredFor(deliveryCheck) is photos_missing, not_as_sample, link_broken, other`; `open() sends the draft fields and returns disputeId`; `open() maps details.code conflict to DisputeError('conflict')`; `watchThread of a missing help thread emits null` (fake Firestore or the adapter's null branch); `SupportMessage maps senderRole staff with name Hỗ trợ`; `Booking maps disputeId`; `EventRegistration maps disputeId`; notification visuals for the four new types.
- [ ] **Step 3:** Run the new test folders; they fail.
- [ ] **Step 4: Implement.** Evidence paths: `disputeEvidence/$uid/$disputeId/${newUlid()}.jpg`. `FirestoreDisputeRepository.mine()` = `disputes where parties array-contains uid orderBy createdAt desc limit 10` (`get`). Messages stream `orderBy createdAt desc limit 30`, reversed for display. `flutter gen-l10n` only if keys are added here (none required).
- [ ] **Step 5:** `flutter analyze` clean; `flutter test --no-pub --timeout 60s test/core`, `test/data/disputes`, `test/data/support`, `test/data/booking`, `test/data/events`, `test/features/notifications`, `test/features/events` green (one folder per command).
- [ ] **Step 6: Commit** `feat(data): dispute and support repositories, shared support email [#142]`.

### Task 6: S18.01 open-dispute sheet and its entries (S05.02, S11.04)

**Files:**
- Create: `app_flutter/lib/features/disputes/dispute_entry.dart`, `open_dispute_sheet.dart`, `open_dispute_controller.dart`; tests `test/features/disputes/open_dispute_sheet_test.dart`, `dispute_entry_test.dart`
- Modify: `lib/features/booking/booking_detail_screen.dart` (`DetailSheet.dispute`, `/b/:id/dispute` in `bookingDetailRoutes()`, the red text button, the banner), `lib/features/booking/booking_view_rules.dart` (`DetailAction.reportProblem` for the customer when `bookingDisputeClosesAt` is in the future and `disputeId == null`), `lib/core/widgets/ticket_card.dart` (`onReportProblem`, `reportProblemLabel` on the compact row), `lib/features/events/tickets_tab.dart`, `lib/l10n/app_vi.arb` (S18.01 + entry strings); tests `test/features/booking/booking_detail_screen_test.dart`, `test/features/booking/booking_view_rules_test.dart`, `test/core/widgets/ticket_card_test.dart`, `test/features/events/tickets_tab_test.dart`

**Interfaces:** Consumes `DisputeRepository`, `imagePickerProvider`, `clockProvider`. Produces the entry API of the Contract (`showOpenDisputeSheet`, `disputeHoursLeft`, `bookingDisputeClosesAt`, `ticketDisputeClosesAt`, `DisputeSubject`, `DisputeSubjectSummary`, `DisputeOrigin`). `OpenDisputeController` (AutoDispose `Notifier<OpenDisputeState>`, keyed by the dispute id it mints on first build): `reason`, `description`, `photos: List<EvidenceSlot {picked, path?, progress, failed}>`, `submitting`, `error`; `pick()` (max 5 − count), `retry(slot)`, `remove(slot)` (deletes the uploaded object), `submit()` → disputeId, `discard()` (deletes every uploaded object).

**Backend wiring:** `openDispute` callable through `FirestoreDisputeRepository.open`; uploads to `disputeEvidence/{uid}/{disputeId}/…` (Storage rule of Task 3); no Firestore read.

**Mock parity:** `#S18.01` (title, window line with `AppIcons.schedule`, chip reasons in this order, description field + counter, "Ảnh bằng chứng · n/5" grid with add tile, lock note, one `AppButton.primary` "Gửi khiếu nại"), `#S18.01-delivery` (title, delivery window line, four chips), `#S05.02-problem` (red text "Báo vấn đề · còn {h} giờ" under the actions), `#S05.02-disputed` (banner with `AppIcons.flag`, "Xem khiếu nại").

- [ ] **Step 1:** Contract check (booking detail, view rules, ticket card, tickets tab); ledger differences.
- [ ] **Step 2: Failing tests:** `the sheet shows the booking reasons in mock order and the window "Còn 18 giờ…"`; `delivery origin shows the delivery title, window copy and four reasons`; `ticket subject shows the ticket reasons and "Tiền vé…"`; `submit is disabled until a reason is picked and the description has 10 characters`; `the counter shows n/1000`; `picking 6 photos keeps 5`; `evidence uploads pass purpose ImagePurpose.document to the uploader` (`FakeMediaUploader.purposes`, #147); `a failed upload shows the retry text and blocks submit until retried or removed`; `submit sends reason code, trimmed description and the uploaded paths, then pops the dispute id`; `conflict shows "Đã có một khiếu nại đang mở cho khoản này."` (and deadline/not-eligible copies); `dragging down after typing asks "Bỏ nội dung đang viết?"`; `closing the sheet after uploads deletes them`. `booking_view_rules_test`: `reportProblem only for the customer of a completed booking inside 24 h with held escrow and no dispute`; `not for upcoming, not after 24 h, not when disputeId is set`. `booking_detail_screen_test`: `the red "Báo vấn đề · còn 18 giờ" opens S18.01 and a success pushes /disputes/:id`; `/b/:id/dispute opens the sheet over S05.02`; `?from=delivery opens the delivery variant`; `a booking with disputeId shows "Đang khiếu nại" for both roles and opens /disputes/:id`; `the resolved banner reads "Khiếu nại đã có kết quả"`. `ticket_card_test`: `compact row shows "Báo vấn đề" only with onReportProblem`. `tickets_tab_test`: `a paid past ticket inside its window shows "Báo vấn đề"; a free one does not`. `dispute_entry_test`: `disputeHoursLeft rounds up and is null at closesAt`.
- [ ] **Step 3:** Run the four test folders; new tests fail.
- [ ] **Step 4: Implement.** Sheet in `showAppSheet` with `canDismiss` asking the discard confirm when anything was entered; `ScreenCode(ScreenCodes.openDispute, …)`; reasons with `ReasonPicker(style: ReasonPickerStyle.chips)`; photo tiles reuse `NetworkPhoto`/file thumbnails at 1:1 in a 3-column grid with a dashed add tile (`AppIcons.addPhoto`); uploads at most 2 at a time. The S05.02 banner is an `EscrowNotice`-styled tappable row (field background, `AppIcons.flag`) shown above the `BookingCard`; the red text button reuses the cancel button's style. Strings into `app_vi.arb`, `flutter gen-l10n`.
- [ ] **Step 5:** `flutter analyze` clean; run `test/features/disputes`, `test/features/booking`, `test/core/widgets`, `test/features/events` (one per command) green.
- [ ] **Step 6: Commit** `feat(disputes): S18.01 open-dispute sheet from S05.02 and S11.04 [#142]`.

### Task 7: S18.02 dispute detail and the shared support thread view

**Files:**
- Create: `app_flutter/lib/features/disputes/dispute_detail_screen.dart`, `lib/features/disputes/widgets/dispute_outcome_card.dart`, `lib/features/help/support_thread_view.dart` (`SupportThreadView({required String threadId, required bool enabled, String? disabledReason, required String hint, required String Function(SupportMessage) senderLabel})`, used by S18.02 and the help chat), `lib/features/help/support_thread_controller.dart` (optimistic send with `clientId = newUlid()`, retry on failure); tests `test/features/disputes/dispute_detail_screen_test.dart`, `test/features/help/support_thread_view_test.dart`
- Modify: `lib/app/router.dart` (`/disputes/:id`), `lib/l10n/app_vi.arb` (S18.02 strings)

**Interfaces:** Consumes `disputeProvider`, `evidenceUrlProvider`, `supportMessagesProvider`, `SupportRepository.send`, `authStateProvider`. Sender labels: staff → `disputeSenderSupport`; provider → `disputeSenderProvider(name)` (`disputeSenderHost` for tickets); customer → `disputeSenderCustomer(name)`; own messages unlabeled (`ChatBubble(mine: true)`); system messages as `SystemContent`.

**Backend wiring:** listeners on `disputes/{id}`, `support_threads/dispute_{id}` and its `messages` (`limit(30)`, rules of Task 3); sending through `sendSupportMessage`; evidence URLs through `MediaUrlResolver.downloadUrl` (Storage rule checks parties).

**Mock parity:** `#S18.02` (title "Khiếu nại #K7Q2", subject card + status badge, key-value block "Tiền đang giữ" with the note and "Gửi lúc", three-step `StatusTimeline`, "Mô tả & ảnh" with a 3-column grid, "Trao đổi" with labelled bubbles, composer "Nhắn cho hỗ trợ…"), `#S18.02-resolved` (toast "Đã có kết quả · {when}", badge "Đã xử lý", outcome rows by role, staff note line, closed text, outline "Liên hệ hỗ trợ" in the footer, no composer).

- [ ] **Step 1:** Contract check (router, `ChatBubble`, `ChatComposer`, `StatusTimeline`).
- [ ] **Step 2: Failing tests:** `customer view of an open dispute: "Khiếu nại #K7Q2", "Đang xem xét", "Tiền đang giữ 1.500.000₫", three steps with "Hỗ trợ đang xem xét" current`; `provider view of a split outcome reads "Hoàn cho khách 600.000₫" and "Chuyển cho bạn 900.000₫"`; `customer view of split reads "Hoàn cho bạn" and "Chuyển cho Minh Trí"`; `release outcome reads "Chuyển tiền cho {name}"; refund reads "Hoàn 100%"`; `platform event release names "ứng dụng"`; `the staff note shows "Ghi chú của hỗ trợ: …"`; `messages are labelled Hỗ trợ / "{name} · nhiếp ảnh gia" / mine unlabelled`; `sending shows the bubble at once and keeps it with a retry when the call fails`; `limit_exceeded shows "Bạn gửi hơi nhanh…"`; `resolved: no composer, the closed text and "Liên hệ hỗ trợ" pushes /help/chat`; `an unknown or forbidden id shows "Không tìm thấy khiếu nại"`; `tapping an evidence photo opens it full screen`; `fits 320dp at 1.3x text`.
- [ ] **Step 3:** Run; they fail.
- [ ] **Step 4: Implement** with `AsyncView`; the composer sits in the bottom bar (`AppFooterBar`), the rest scrolls; no `AppButton.primary` on this screen (send is the composer's own button). Route `/disputes/:id` outside the tab shell. Strings + `flutter gen-l10n`.
- [ ] **Step 5:** `flutter analyze` clean; `test/features/disputes`, `test/features/help` green.
- [ ] **Step 6: Commit** `feat(disputes): S18.02 dispute detail with outcome and support thread [#142]`.

### Task 8: S18.03 help, support chat and the settings entry

**Files:**
- Create: `app_flutter/lib/features/help/help_screen.dart`, `help_faq.dart` (`List<FaqTopic> faqTopics(AppLocalizations l)`; `FaqTopic {id, label, items: List<(question, answer)>}`), `support_chat_screen.dart`; tests `test/features/help/help_screen_test.dart`, `support_chat_screen_test.dart`
- Modify: `lib/app/router.dart` (`/help`, `/help/chat`), `lib/features/settings/settings_screen.dart` (group "Hỗ trợ" with the "Trợ giúp" tile, `Key('settings-help')`, `AppIcons.help`, placed after the "Thông báo" group and before "Đăng xuất", per Decision 12 of `2026-10-07-s09-profile-settings.md`; if #148 has rebuilt the screen, add the group to its `_SectionLabel` + `GlassCard` structure and ledger the merge), its test, `lib/l10n/app_vi.arb`

**Interfaces:** Consumes `myDisputesProvider`, `SupportThreadView` (Task 7), `supportEmail`, `supportEmailUri()`, `externalLauncherProvider`.

**Backend wiring:** `get` of `disputes where parties array-contains uid orderBy createdAt desc limit 10` (index of Task 3); help chat listener on `support_threads/help_{uid}` (+ messages) and `sendSupportMessage` without thread id.

**Mock parity:** `#S18.03` (sections in order: "Khiếu nại của bạn" only when there is one, "Câu hỏi thường gặp" with topic chips and expandable rows, one `AppButton.primary` "Liên hệ hỗ trợ" with `AppIcons.supportAgent` in the footer, email line only when set), `#S18.03-chat` (title "Hỗ trợ", lock note, bubbles, composer "Nhắn cho hỗ trợ…", empty text).

Strings (exact): `helpTitle` "Trợ giúp"; `helpMyDisputes` "Khiếu nại của bạn"; `helpDisputeRow` "Khiếu nại #{code} · {name}"; `helpDisputeRowMeta` "{status} · {date}"; `helpFaqTitle` "Câu hỏi thường gặp"; `helpContactSupport` "Liên hệ hỗ trợ"; `helpEmailLine` "Email hỗ trợ: {email}"; `supportChatTitle` "Hỗ trợ"; `supportChatNote` "Chỉ bạn và đội hỗ trợ xem được cuộc trò chuyện này. Đừng gửi mật khẩu hay mã OTP."; `supportChatHint` "Nhắn cho hỗ trợ…"; `supportChatEmpty` "Bạn cần giúp gì? Nhắn cho đội hỗ trợ, chúng tôi trả lời tại đây và báo cho bạn khi có tin mới."
Topics: `helpTopicPayments` "Thanh toán"; `helpTopicCancel` "Huỷ & hoàn tiền"; `helpTopicDelivery` "Bàn giao ảnh"; `helpTopicDisputes` "Khiếu nại"; `helpTopicContact` "Liên hệ"; `helpTopicReviews` "Đánh giá"; `helpTopicProviders` "Dành cho thợ ảnh".
FAQ (question / answer, exact):
- `helpPayFullQ` "Vì sao phải trả trước 100%?" / `helpPayFullA` "Tiền không đến tay thợ ngay. Ứng dụng giữ tiền và chỉ chuyển cho thợ theo 2 đợt: sau buổi chụp, và sau khi bạn đồng ý ảnh rồi kiểm tra bộ ảnh gốc trong 48 giờ. Có lỗi thì bạn được hoàn qua ứng dụng."
- `helpPayHeldQ` "Tiền của tôi được giữ ở đâu?" / `helpPayHeldA` "Tiền do một tổ chức trung gian thanh toán được cấp phép giữ, không nằm trong tài khoản của ứng dụng, và chưa chuyển cho thợ cho tới khi đủ điều kiện."
- `helpPayQrQ` "Chuyển khoản QR sai số tiền thì sao?" / `helpPayQrA` "Hãy chuyển đúng số tiền và nội dung trong 15 phút. Chuyển thiếu, thừa hoặc sau khi QR hết hạn sẽ được hoàn tự động về tài khoản đã chuyển."
- `helpCancelRefundQ` "Huỷ buổi chụp được hoàn bao nhiêu?" / `helpCancelRefundA` "Huỷ trước giờ chụp từ 48 giờ trở lên: hoàn 100%. Từ 24 đến 48 giờ: hoàn 50%. Dưới 24 giờ: không hoàn. Tính trên toàn bộ số đã trả. Thợ huỷ thì bạn được hoàn 100%."
- `helpCancelWhereQ` "Tiền hoàn về đâu?" / `helpCancelWhereA` "Trả bằng ví MoMo hoặc ZaloPay thì hoàn về ví. Chuyển khoản thì hoàn về tài khoản đã chuyển, hoặc tài khoản khác bạn khai."
- `helpCancelLateQ` "Thợ giao ảnh trễ thì sao?" / `helpCancelLateA` "Quá số ngày đã hẹn, bạn được huỷ phần bàn giao và hoàn 100% đợt thanh toán thứ hai; thợ giữ đợt đầu."
- `helpDeliverySampleQ` "Ảnh mẫu có watermark là gì?" / `helpDeliverySampleA` "Thợ gửi ảnh mẫu có watermark trước. Link bộ ảnh gốc bị che và chỉ mở khi bạn bấm \"Đồng ý ảnh\". Không phản hồi trong 3 ngày thì hệ thống tự đồng ý."
- `helpDeliveryEditQ` "Muốn sửa ảnh thì làm sao?" / `helpDeliveryEditA` "Trao đổi màu sắc, chỉnh sửa ngay trên ảnh mẫu. Số vòng sửa miễn phí theo gói. Hết lượt thì bạn đồng ý, xin thêm một vòng, hoặc mở khiếu nại."
- `helpDisputeWhenQ` "Khi nào tôi mở khiếu nại được?" / `helpDisputeWhenA` "Trong 24 giờ sau khi buổi chụp hoàn thành, hoặc trong 24 giờ sau khi sự kiện có vé trả tiền kết thúc. Với bộ ảnh gốc, bạn có 48 giờ kể từ khi đồng ý ảnh. Quá thời hạn thì nút \"Báo vấn đề\" không còn. Vé không thu phí không có khiếu nại vì không có tiền được giữ."
- `helpDisputeMoneyQ` "Trong lúc khiếu nại, tiền ở đâu?" / `helpDisputeMoneyA` "Tiền tiếp tục được giữ, không chuyển cho thợ. Đội hỗ trợ xem bằng chứng của hai bên rồi quyết định: chuyển cho thợ, hoàn cho bạn, hoặc chia."
- `helpDisputeEvidenceQ` "Ai xem được ảnh bằng chứng?" / `helpDisputeEvidenceA` "Chỉ bạn, người bị khiếu nại và đội hỗ trợ."
- `helpContactQ` "Khi nào tôi gọi được cho thợ?" / `helpContactA` "Gọi, Zalo, WhatsApp chỉ mở sau khi bạn đã thanh toán. Trước đó bạn nhắn tin hỏi trong ứng dụng. Số điện thoại không hiện công khai."
- `helpReviewQ` "Cà chua và gạch là gì?" / `helpReviewA` "Cà chua là hài lòng, gạch là chưa hài lòng; bấm 1 đến 10 lần để nói mức độ. Hồ sơ thợ hiện tỉ lệ cà chua. Mỗi buổi chụp đánh giá một lần, gửi rồi không sửa."
- `helpProviderStartQ` "Làm sao để bắt đầu nhận đơn?" / `helpProviderStartA` "Xác minh số điện thoại, đóng phí xác minh (thợ ảnh 99.000₫, studio 299.000₫, không hoàn), xác minh danh tính bằng VNeID hoặc chip CCCD và đồng ý quy định nhận việc. Nhân viên duyệt trong 24 giờ."
- `helpProviderPaidQ` "Khi nào tôi nhận được tiền?" / `helpProviderPaidA` "Tiền về theo 2 đợt: sau buổi chụp, và sau khi khách đồng ý ảnh và hết 48 giờ kiểm tra. Chi tự động mỗi ngày vào tài khoản đã xác minh; lần chi đầu do nhân viên duyệt."
Topic membership: payments (PayFull, PayHeld, PayQr), cancel (CancelRefund, CancelWhere, CancelLate), delivery (DeliverySample, DeliveryEdit), disputes (DisputeWhen, DisputeMoney, DisputeEvidence), contact (Contact), reviews (Review), providers (ProviderStart, ProviderPaid).

- [ ] **Step 1:** Contract check (settings sections, router).
- [ ] **Step 2: Failing tests:** `help shows "Khiếu nại của bạn" with "Khiếu nại #K7Q2 · Minh Trí" / "Đang xem xét · 14/10" only when the user has disputes`; `tapping a dispute row pushes /disputes/:id`; `topic chips switch the questions; the first topic is Thanh toán`; `a question expands to its exact answer and collapses again (semantics expanded state)`; `every FAQ key has a non-empty question and answer` (iterate `faqTopics`); `"Liên hệ hỗ trợ" pushes /help/chat`; `the email line is hidden when supportEmail is null and opens mailto when set` (inject through a provider override of a `supportEmailProvider` that defaults to `supportEmail`); `support chat empty state shows the empty text and the lock note`; `sending creates the help thread through send(threadId: null)`; `settings shows the "Hỗ trợ" group after "Thông báo" and before "Đăng xuất"; "Trợ giúp" opens /help`; `help fits 320dp at 1.3x text`.
- [ ] **Step 3:** Run; they fail.
- [ ] **Step 4: Implement.** Expandable rows: `ExpansionTile`-free custom row (glass card rows like the mock, `AppIcons.expandMore` rotated), `Semantics(expanded:)`. Strings + `flutter gen-l10n`.
- [ ] **Step 5:** `flutter analyze` clean; `test/features/help`, `test/features/settings` green; `dart run tool/affected_test.dart origin/develop --run` green.
- [ ] **Step 6: Commit** `feat(help): S18.03 help with FAQ, my disputes and support chat [#142]`.

### Task 9: Docs, data model, ledger and status

**Files:**
- Modify: `docs/superpowers/specs/2026-10-01-remaining-screens.md` (§2 S18 status cells → "✅ đã làm (#142)"), `docs/superpowers/specs/data-model/domain-model.md` (`Dispute`, `SupportThread`, `SupportMessage` rows; `Payment.dispute` shape; `DisputeStatus`, `DisputeOutcomeKind`, `DisputeReason` enums; escrow state machine note "disputed → prevEscrowStatus → released|refunded|partially_refunded"), `relational-schema.md` (`disputes`, `support_threads`, `support_messages` DDL + Firestore mapping rows), `data-model/README.md` (`resolve_dispute` row: callable `resolveDispute` + CLI; `send_support_message`), `docs/superpowers/specs/screens/disputes-help.md` (Trạng thái "Đã có"), `docs/legal/terms-and-help-notes.md` (one line under P8: the FAQ keys that quote it), `docs/FIREBASE-SETUP.md` (only if it lists callables/indexes; add the three new ones)
- Create: `docs/superpowers/handover/ledger-s18-disputes-help.md`

- [ ] **Step 1:** Edit the docs (Vietnamese specs, English code names). Check every S18 string in `screens/disputes-help.md` against `app_vi.arb` and the mock.
- [ ] **Step 2:** Ledger: rulings taken while implementing, rules/Storage/integration tests written not run, deploy order (indexes before the app release that queries `disputes`; Functions `openDispute` re-point and the app ship together since no client used the old shape), extension points handed to #129/#130 (`findSubjectPayment`, `disputeWindow`, `DisputeOrigin.deliveryCheck` + `/b/:id/dispute?from=delivery`), and the temporary FAQ/app copy mismatch if #129/#130 have not landed.
- [ ] **Step 3: Commit** `docs(spec): S18 disputes and help in the data model, ledger [#142]`.

## Deferred

- Real payment intermediary, real refunds and payouts (#129 and the payments spec §10–11); disputes run on the fake gateway.
- Staff dashboard screens S23.01 (dispute queue) and S23.06 (support inbox) — phase 1.5 (#83); phase 1 uses `resolveDispute` + CLIs.
- Milestone-level freezing and the `approved` / 48-hour delivery window (#130 extends `findSubjectPayment` and `disputeWindow`); provider-opened disputes after "hết lượt sửa" (#130).
- Withdrawing a dispute (Needs the owner 2); evidence purge job (Needs the owner 3); images in support chat; staff "reviewing" sub-state.
- "Chụp ngay" FAQ (S13 plans); self-hosted parity (`services/api` has no disputes; Go backend phase 2 #90).
- Analytics events (no analytics layer, as in earlier plans).
