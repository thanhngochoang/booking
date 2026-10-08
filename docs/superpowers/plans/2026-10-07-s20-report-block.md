# S20 · Báo cáo & chặn (S20.01–S20.02) Implementation Plan

> **Rules emulator tests (2026-10-02, user):** this plan changes `firestore.rules` and `firestore.indexes.json` and adds callables. Write the rules tests and the Functions integration test; do not run them, CI runs them. Record the skips in the ledger.

> **No battery/performance, device build or iOS steps** (standing rules in `RUN-ORDER.md`).

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

> **Detail level (user, 2026-10-02):** exact interfaces, tests listed by name with expected behaviour, sample code only for the parts easy to get wrong.

**Goal:** From a profile, a post, a message or an event, anyone can report it with a fixed reason, an optional note and "Chặn luôn"; reports are stored for staff (CLI now, dashboard in phase 1.5); blocking someone hides each other's content both ways, closes chat between them and makes the server refuse new bookings, inquiries, contact links and event registrations between the two; S20.02 lists the people you blocked and unblocks them.

**Architecture:** Rules in `packages/domain` (new `block*.ts`, `report*.ts`; #198's `BlockGate` port, already used by the shared order gate `orderBlocker` for `createBookingDraft` and `createPayment`, is plugged into `openInquiry`, `getContactLink`, `registerEvent`, and a `blockedAt` field on the 1‑1 `Chat` checked by `assertCanSend`). Server-written data only: `blocks/{blockerId}_{blockedId}` (with the blocked person's name and avatar for S20.02), a per-user index `users/{uid}/private/blocks` `{blockedIds, blockedByIds}` (one document the app listens to), `reports/{id}`, `users/{uid}/private/report_quota`. Three callables (`blockUser`, `unblockUser`, `submitReport`) and a staff CLI `npm run reports` (list, show, dismiss, takedown). The app gets `lib/data/safety/` (Firestore adapter + fake), `features/safety/` (S20.01 sheet, the shared "…" menu, S20.02, blocked states), wires the existing disabled "Báo cáo · Sắp có" row of S11.05 and adds report/block entries on S03.01, S02.02, S07.01, S11.06, S11.02 and S24.01, and filters hidden users out of feed, Find, timeline and group chat.

**Tech Stack:** TypeScript (domain, Functions v2 callables, Admin SDK, `node --test`), Firestore rules and indexes; Flutter, Riverpod 3, go_router, existing core widgets (`showAppSheet`, `showConfirmSheet`, `ReasonPicker` radio style, `AppOptionTile`, `ChatComposer(enabled, disabledReason)`, `EmptyState`, `AsyncView`).

**Spec:** `docs/superpowers/specs/2026-10-01-remaining-screens.md` §2 (S20 rows), §3i.3 (S20), §3.7 (timeline and group-chat moderation, "báo cáo tin nhắn"), §3i.6 (staff audit), §8 questions 21, 24; `docs/superpowers/specs/data-model/README.md` (ports), `domain-model.md`; mock `docs/design/ui-mock.html` `#S02.02` (`more_horiz` already in the hero), `#S03.01`, `#S07.01`, `#S11.02`, `#S11.05`, `#S11.06`, `#S24.01`, frames added by Task 1; ledgers `ledger-events-10c.md` ("Report sheet … until S20.01"), `ledger-c-portfolio-albums-9b-2-L1.md` ("Visitors get no "…" menu on S24.01 until "Báo cáo" (S20.01) exists").

**Issue:** #144. **Execution wave:** 3 (cross-plan review 2026-10-07). **Blocked by:** #198 (Nền · Cổng nhận đơn, plan `2026-10-08-n1-order-gate.md`: `OrderGateDeps`, `orderBlocker`, `assertOrderAllowed`, `BlockGate`, `blockDocId`, `FakeBlockGate`, error code `blocked`, `FirestoreBlockGate`, `liveBlockGate()`, `BookingErrorCode.blocked`, `bookingErrBlocked`; `createBookingDraft` and `createPayment` already refuse a blocked pair once `blocks/*` documents exist). #129 (S04), #131 (S07: chat mapping and the shared `chat round-trips every field` test) and #148 (S09: settings order) are merged. Since the 2026-10-08 replan the order paths (#139, #140, #136, #151) wait for #198, not for this plan; they start refusing blocked pairs as soon as this plan writes the block documents. **Owns:** writing blocks (`blocks/{blockerId}_{blockedId}`, the per-user index, `blockUser`/`unblockUser`), reports, the non-order block checks (inquiry, message, contact link, event registration). `BlockGate` and the error code `blocked` are #198's. Previously: none hard. Soft: #142 (S18) for the "liên hệ hỗ trợ" link on a blocked booking (text only until `/help` exists); #131 (S07 chat plan `2026-10-07-s07-chat.md`, Decision 12: the S07.01 "…" menu, `bookingStatus` on chats) shares `infra/chat_firestore.ts` and `chat_screen.dart`; #148 (S09 settings rebuild) for the settings row placement; #143 (S19) lists filter hidden users once both exist. **Branch:** `plan/144-s20-report-block`, PR into `develop` titled `feat(safety): S20 report sheet, blocking and blocked users [#144]`.

## Contract with existing code

Checked 2026-10-07 on `develop` 812afd6; order gate re-planned 2026-10-08: the gate is done in #198 (`2026-10-08-n1-order-gate.md`), so after #198 `createBookingDraft` and `createPayment` call `assertOrderAllowed` (`order_gate.ts`), `BookingDeps.blocks: BlockGate` is required and wired to `liveBlockGate()`, and the booking test world carries a `FakeBlockGate`. The first step of every task re-checks the names it uses; adapt and ledger any difference. If a member named here does not exist, stop and report instead of guessing.

- Domain (`packages/domain/src`): `ERROR_CODES` (`errors.ts`; has `blocked` from #198); from #198: `BlockGate {isBlockedEitherWay(a, b)}` and `blockDocId(blockerId, blockedId)` (`block_ports.ts`), `FakeBlockGate` (`fake_block_gate.ts`: `block`, `unblock`, `calls`), `OrderGateDeps`, `orderBlocker`, `assertOrderAllowed` (`order_gate.ts`); `createBookingDraft(deps: BookingDeps, rawInput)` (`create_booking.ts`; service check → `assertOrderAllowed` → price → phone → …), `BookingDeps {store, services, providers, blocks, contacts, gateway, clock, ids}` (`booking_ports.ts`); `openInquiry(deps: ChatDeps, {customerId, photographerId})`, `sendMessage(deps, {senderId, chatId, message})`, `assertCanSend(chat, senderId, now)`, `Chat` (no `blockedAt`), `chatIdFor(customerId, photographerId)` = `{customerId}_{photographerId}`, `ChatDeps {chats, photographers, clock, ids}` (`chat.ts`, `chat_ports.ts`, `open_inquiry.ts`, `send_message.ts`); `getContactLink(requesterId, data, deps: GetContactLinkDeps)` (`get_contact_link.ts`); `registerEvent(deps: RegisterDeps, caller, raw)` (`event_registration.ts:73`, `RegisterDeps = EventDeps & {gateway?}`, `EventDeps {events, people, contacts, media, clock, ids, random}`); event host `host.type` / `hostId`; event group chat moderation `moderateEventChat` (`delete` sets `deletedAt`), timeline moderation `moderateEventTimeline` (`hide`). Test worlds that build these deps: `test/support/booking_world.ts`, `chat_world.ts`, `event_world.ts`, `event_social_world.ts`, plus `get_contact_link.test.ts`.
- Functions (`app_flutter/firebase/functions/src`): `toHttpsError` + `TRANSPORT_CODE` (`callables/errors.ts`; `blocked: 'failed-precondition'` from #198); from #198: `FirestoreBlockGate` (`infra/safety_firestore.ts`, one `getAll` of `blocks/{a}_{b}` and `blocks/{b}_{a}`), `liveBlockGate()` (`infra/live_safety.ts`); `liveBookingDeps()` (`infra/live_booking.ts`, already `blocks: liveBlockGate()`), `liveChatDeps()` (`infra/live_chat.ts`), `liveContactDeps()` (`infra/live.ts`), `liveEventDeps()`/`live_event.ts`; `toFirestoreChat` / `fromFirestoreChat` (`infra/chat_firestore.ts:13,34`; written with `merge: true`); staff CLI pattern `tools/awards.ts`; seed `seed/fixtures.ts` (Lan, Minh, An, Bình, Cúc, Dũng, admin), `seed/README.md`. Self-hosted `services/api/src/use-cases/get-contact-link.ts` has its own decision (not the domain one).
- Rules: `users/{uid}/private/{docId}` read by the owner, client writes only `contact` and `notification_prefs` (so `blocks` and `report_quota` are already server-only); no `blocks`, no `reports`; catch-all deny.
- App data: `ChatThread` (`lib/data/chat/chat.dart`, no `blockedAt`), `ChatErrorCode` (no `blocked`) + `ChatException` (`chat_repository.dart`), `FirestoreChatRepository` mapping; `BookingErrorCode` (has `blocked` from #198) + `bookingErrorOf` + `_codeToBookingError` (`lib/data/booking/booking_repository.dart`); l10n `bookingErrBlocked` (#198, shown by the booking sheet and S04.04); `EventError(code)` (`lib/data/events/event_repository.dart`, `callEventFunction`); `UserRepository.watch(uid)`; `authStateProvider`; `PostSummary` (`authorId`, `photographerId`, `eventId`, `imageUrls`, `caption`).
- App features: S11.05 `_menu` with the disabled row `Key('timeline-report')` (`label: l.timelineReport`, `trailing: l.timelineReportSoon`, `onTap: null`) in `features/events/timeline_tab.dart:~206`; S11.06 long-press menu `_messageMenu` only for moderators (`event_chat_screen.dart:115, 476`; non-moderators get no menu); S07.01 AppBar `PopupMenuButton` only when `thread.bookingId != null` (`chat_screen.dart:~419`); S03.01 `PhotographerProfileScreen._loaded` AppBar (leading back only); S02.02 hero has only the back button (`photo_detail_screen.dart:~143`; mock has `more_horiz`); S11.02 `_Cover(onBack, onShare, …)` (`event_screen.dart:~305`); S24.01 album detail owner-only "…" (`album_detail_screen.dart:~226`); home feed `HomeController` (`features/home/home_controller.dart`), Find `FindResultsController` (`features/find/find_controller.dart`, `_visible` filter from #133), booking detail `BookingDetailScreen` contact/message actions (`booking_detail_screen.dart`, `_contact`, `DetailAction.message|contact`); `SettingsScreen` (`features/settings/settings_screen.dart`).
- Core: `ScreenCodes.report` (S20.01), `blockedUsers` (S20.02) exist (`lib/core/screen_codes.dart:110-111`); `AppIcons.flag`, `AppIcons.more`, `AppIcons.share`; no `AppIcons.block`. l10n `timelineReport` "Báo cáo", `timelineReportSoon` "Sắp có".

## Global Constraints

- Spec §3i.3, verbatim: "menu "…" trên hồ sơ, bài, tin nhắn (nhấn giữ), sự kiện → S20.01 (lý do cố định + mô tả, tuỳ chọn "Chặn người này") → hàng đợi S23.05." "**Chặn**: hai bên không thấy bài của nhau trong feed, không nhắn được, không đặt lịch được với nhau (booking đang có vẫn giữ để không mất tiền; liên hệ đi qua hỗ trợ); bỏ chặn ở S20.02." "Cửa hàng ứng dụng cũng yêu cầu báo cáo và chặn cho nội dung do người dùng tạo."
- Spec §3i.6: "mọi quyết định của staff ghi nhật ký kiểm toán (ai, lúc nào, lý do)".
- Contact rule (CLAUDE.md): a block never opens a new outside channel; on a blocked booking the external `ContactDial` and chat stay closed and the copy points to support.
- Server-enforced where it matters (owner ruling for this issue): bookings, inquiries, 1‑1 messages, contact links and event registrations are refused by the server whatever the client does. Hiding content is client-side from the server-written index.
- CLAUDE.md: rules in `packages/domain` (no Firebase/Node imports); Functions thin, region `asia-southeast1`; Firebase only in `lib/data/**`; strings in `lib/l10n/app_vi.arb` + `flutter gen-l10n`; `AppColors`/`AppSpace`/`AppRadius`/`AppIcons`; `package:photobooking/...` imports, features import `core/core.dart`; one `AppButton.primary` per screen/sheet; every screen/sheet in `ScreenCode`; `AsyncView` for every `AsyncValue`; red actions only in sheets or as red text.
- Ids/time (`data-model/README.md`): block ids `{blockerId}_{blockedId}`; report ids deterministic (Decision 6); UTC timestamps; string enum codes.
- Commits: Conventional Commits, subject ends with `[#144]`, footer `Co-Authored-By: TonyH <thanhngochoangbk@gmail.com>`.
- Env for Flutter commands (from `app_flutter/`): `source ../scripts/env.sh && export HOME="$PWD/../.home" && export PATH="$PWD/../.flutter/bin:$PATH"`.
- Tests: `flutter test --no-pub --timeout 60s <file or folder>`, one folder at a time; bounded pumps; domain `cd packages/domain && npm test && npm run lint`; functions `cd app_flutter/firebase/functions && npm test && npm run build`; rules-test and Functions integration suites are written, not run.

## Decisions (where the spec is silent)

1. **Block storage.** `blocks/{blockerId}_{blockedId}` `{blockerId, blockedId, blockedName, blockedAvatarUrl, source: 'menu'|'report', createdAt}` (name and avatar copied at block time: S20.02 needs no user reads) and the index `users/{uid}/private/blocks` `{blockedIds: string[], blockedByIds: string[], updatedAt}` for both users, all written by `blockUser` / `unblockUser` in one transaction. At most 500 blocks per user (`limit_exceeded`). Blocking yourself or an unknown user → `invalid_argument` / `not_found`. Repeated block → unchanged (idempotent).
2. **What the server refuses** (error code `blocked`, transport `failed-precondition`, both from #198): every order path, through the shared `orderBlocker` (Done in #198 (`2026-10-08-n1-order-gate.md`): `OrderGateDeps.blocks`, the check after the provider gate, `createBookingDraft` and `createPayment` through `assertOrderAllowed`; the later quote, studio, collaborator and Chụp ngay paths call it too; this plan only writes the `blocks/*` documents the gate reads), and, added by this plan, `openInquiry` when the chat does not exist yet, `sendMessage` when `chat.blockedAt` is set, `getContactLink` for a booking whose two parties are blocked either way (logged as not granted), `registerEvent` when the host is a photographer blocked either way. Order paths of later plans (quotes #139: `submitQuote`, `inviteToJob`, `acceptQuote`; Chụp ngay #140: each invitee at offer creation; studio #136: `assignBooking`, customer ↔ assignee; collaborators #151: `applyToRecruitPost`, `inviteCollaborator`, collaborator assignment) call `orderBlocker` / `BlockGate.isBlockedEitherWay` themselves (written into their plans by the cross-plan review, finding 22).
3. **Chat flag.** One 1‑1 chat exists per pair (`chatIdFor`). `blockUser` sets `chats/{a}_{b}` and `chats/{b}_{a}` `blockedAt` when they exist; `unblockUser` clears it only when no block remains in either direction. `toFirestoreChat` / `fromFirestoreChat` must carry `blockedAt`, or the next booking status sync (written with `merge: true` from the domain object) would erase it (Review Focus 1). Group chats are not blocked server-side (the host moderates); each side hides the other's messages.
4. **Side effects of a block.** Follows both ways (`follows/{a}_{b}`, `follows/{b}_{a}`) and saved-photographer markers both ways (`savedPhotographers/…`, if #143 landed; deleting a missing document is fine) are deleted in the same transaction. Bookings, tickets and their money are untouched (spec). No notification to the blocked person.
5. **Hiding (client, from the index).** Hidden = `blockedIds ∪ blockedByIds`. Applied to: home feed and "Thêm của …" sections (posts whose `photographerId` or `authorId` is hidden), Find S02.06 and Home shelves (photographers), S03.01 (blocked-by-me → "Bạn đã chặn {name}" + "Bỏ chặn"; blocked-by-them → "Không xem được hồ sơ này"), S02.02 of a hidden author ("Không xem được bài này"), S11.05 timeline tiles, S11.06 messages from hidden senders, S19 lists if present. S07.02 keeps the conversation row; S07.01 shows the closed composer (Decision 3). S05.02 of a blocked pair hides "Nhắn tin" and `ContactDial` and shows "Hai bên đã chặn nhau. Cần trao đổi về buổi chụp, hãy liên hệ hỗ trợ." (+ "Liên hệ hỗ trợ" → `/help/chat` only when that route exists, #142).
6. **Reports.** `reports/{reporterId}_{targetType}_{targetKey}` (targetKey = target id; for messages `{chatId}~{messageId}`): a second report of the same target by the same person returns `duplicate: true` and changes nothing. Fields: `reporterId, targetType ('user'|'post'|'message'|'event'), targetId, chatId|null, targetOwnerId|null, reason, text|null, blocked: bool, snapshot {name|null, excerpt|null (≤ 300 graphemes), imageUrl|null}, status ('open'|'dismissed'|'actioned'), staffNote|null, decidedBy|null, decidedAt|null, createdAt`. The snapshot keeps what was reported even if it is deleted later (staff need it). No client reads. Limit 20 reports per reporter per Vietnam day (`users/{uid}/private/report_quota` `{day, count}`; `limit_exceeded`).
7. **Reasons** (fixed codes): `spam`, `scam`, `harassment`, `inappropriate`, `stolen_photos`, `impersonation`, `other`; `other` needs a note of at least 10 characters; the note is optional otherwise, ≤ 500. Same list for every target ("scam" covers "đòi chuyển tiền ngoài ứng dụng", the platform's main risk).
8. **Targets validated by the server.** `user`: `users/{id}` exists, not the reporter. `post`: `posts/{id}` exists; owner = `authorId`. `message`: `chats/{chatId}` has the reporter in `members`, the message exists; owner = `senderId` (system messages refused). `event`: `events/{id}` not draft; owner = `hostId` (null for platform events → "Chặn luôn" ignored). Reporting your own content → `invalid_argument`.
9. **"Chặn luôn"** runs the block inside `submitReport` after the report write (same callable, so one tap does both); the result says `blocked: true|false`. The checkbox is hidden when the owner is null or is the reporter.
10. **Staff, phase 1.** `npm run reports -- list [open|dismissed|actioned] | show <id> | dismiss <id> "<note>" --actor <uid> | takedown <id> "<note>" --actor <uid>` (`--actor` with `staffRole == 'admin'`). `takedown`: post → hide its event timeline row (domain `moderateEventTimeline` `hide` as admin, when the post has `eventId`) and delete `posts/{id}`; message → set `deletedAt`, empty body and image on the message (the app shows "Tin nhắn đã bị gỡ"); user → Admin Auth `updateUser(uid, {disabled: true})` + `revokeRefreshTokens`; event → refused with "cancel it in S12.03 with an admin account". Every decision writes `status`, `staffNote`, `decidedBy`, `decidedAt`. The S23.05 queue is phase 1.5 (#83).
11. **Entry points.** S03.01 (visitor): the mock's `ios_share` becomes `more_horiz` → menu "Chia sẻ hồ sơ" (copies `/u/{uid}`, the album/event precedent; fixes the "không nút chia sẻ" gap), "Báo cáo", "Chặn {name}" / "Bỏ chặn {name}". S02.02 (not own post): `more_horiz` in the hero (already in the mock) → "Báo cáo bài viết", "Chặn {name}". S07.01: "…" always present (S07 plan Decision 12 expects this) → existing items + "Báo cáo", "Chặn {name}"; long-press on the other person's message → "Báo cáo tin nhắn". S11.06: long-press on someone else's message for every member → "Báo cáo tin nhắn", "Chặn {name}" (moderators keep pin/delete above). S11.05: the "Báo cáo · Sắp có" row becomes active ("Báo cáo bài viết") for posts not by me. S11.02: `more_horiz` beside share on the cover → "Báo cáo sự kiện". S24.01 (visitor): "…" → "Báo cáo {name}" (user target, the album owner). S20.02 from S09.02 "Người đã chặn".
12. **Block confirm** is a `showConfirmSheet` with the red "Chặn" (danger); unblock uses `danger: false` (not destructive).

## Needs the owner

1. **Open question 24** (block while a booking is running): default as spec — the booking stays, chat and outside contact stay closed, the two talk through support (S18 thread or help chat). Alternative: free cancellation for the blocker.
2. **Should the blocked person see "Không xem được hồ sơ này"** (reveals the block) or a generic "Không tìm thấy"? Default: the explicit text (common practice, and they cannot message anyway).

## Contract

### Data (Firestore, server-written)

- `blocks/{blockerId}_{blockedId}`: `blockerId`, `blockedId`, `blockedName`, `blockedAvatarUrl|null`, `source`, `createdAt`.
- `users/{uid}/private/blocks`: `blockedIds: string[]`, `blockedByIds: string[]`, `updatedAt`.
- `chats/{chatId}.blockedAt: Timestamp|null` (1‑1 chats only).
- `reports/{reportId}` (Decision 6) and `users/{uid}/private/report_quota` `{day: 'yyyy-MM-dd', count}`.

### Domain (`packages/domain/src`)

```ts
// errors.ts: 'blocked' — Done in #198 (`2026-10-08-n1-order-gate.md`)

// block.ts
export const MAX_BLOCKS = 500;
export const BLOCK_SOURCES = ['menu', 'report'] as const;
export type BlockSource = (typeof BLOCK_SOURCES)[number];
export interface BlockRecord { readonly blockerId: string; readonly blockedId: string; readonly blockedName: string;
  readonly blockedAvatarUrl: string | null; readonly source: BlockSource; readonly createdAt: string }
export interface BlockIndex { readonly blockedIds: readonly string[]; readonly blockedByIds: readonly string[] }
export const EMPTY_BLOCK_INDEX: BlockIndex;
// blockDocId(blockerId, blockedId) — Done in #198 (`block_ports.ts`); import it, do not redefine
export function withBlock(index: BlockIndex, other: string, direction: 'blocked' | 'blockedBy'): BlockIndex;     // set semantics
export function withoutBlock(index: BlockIndex, other: string, direction: 'blocked' | 'blockedBy'): BlockIndex;
export function blockedEitherWay(index: BlockIndex, other: string): boolean;

// block_ports.ts (created by #198 with `BlockGate { isBlockedEitherWay(a, b): Promise<boolean> }` and `blockDocId`;
// this plan adds the members below to the same file)
export interface BlockTx {
  getBlock(blockerId: string, blockedId: string): Promise<BlockRecord | null>;
  getIndex(uid: string): Promise<BlockIndex>;                         // EMPTY_BLOCK_INDEX when missing
  chatExists(chatId: string): Promise<boolean>;
  putBlock(b: BlockRecord): void;
  deleteBlock(blockerId: string, blockedId: string): void;
  putIndex(uid: string, index: BlockIndex, at: string): void;
  setChatBlockedAt(chatId: string, at: string | null): void;
  deleteFollowMarkers(a: string, b: string): void;                    // follows + savedPhotographers, both directions
}
export interface BlockStore { runTransaction<T>(fn: (tx: BlockTx) => Promise<T>): Promise<T> }
export interface PublicProfiles { get(uid: string): Promise<{ name: string; avatarUrl: string | null } | null> }
export interface BlockDeps { readonly store: BlockStore; readonly profiles: PublicProfiles; readonly clock: Clock }

// block_use_cases.ts
/** `{userId, source?}`; idempotent; throws invalid_argument (self/malformed), not_found, limit_exceeded. */
export async function blockUser(deps: BlockDeps, callerId: string, raw: unknown): Promise<BlockRecord>;
/** `{userId}`; a missing block is a no-op. Clears chat blockedAt only when no block remains either way. */
export async function unblockUser(deps: BlockDeps, callerId: string, raw: unknown): Promise<void>;

// report.ts
export const REPORT_TARGETS = ['user', 'post', 'message', 'event'] as const;
export type ReportTargetType = (typeof REPORT_TARGETS)[number];
export const REPORT_REASONS = ['spam', 'scam', 'harassment', 'inappropriate', 'stolen_photos', 'impersonation', 'other'] as const;
export type ReportReason = (typeof REPORT_REASONS)[number];
export const REPORT_TEXT_MAX = 500;
export const REPORT_OTHER_MIN = 10;
export const REPORTS_PER_DAY = 20;
export const REPORT_STATUSES = ['open', 'dismissed', 'actioned'] as const;
export interface ReportTargetView { readonly type: ReportTargetType; readonly id: string; readonly chatId: string | null;
  readonly ownerId: string | null; readonly snapshot: { readonly name: string | null; readonly excerpt: string | null; readonly imageUrl: string | null } }
export interface Report { readonly id: string; readonly reporterId: string; readonly targetType: ReportTargetType;
  readonly targetId: string; readonly chatId: string | null; readonly targetOwnerId: string | null; readonly reason: ReportReason;
  readonly text: string | null; readonly blocked: boolean;
  readonly snapshot: { readonly name: string | null; readonly excerpt: string | null; readonly imageUrl: string | null };
  readonly status: (typeof REPORT_STATUSES)[number]; readonly staffNote: string | null; readonly decidedBy: string | null;
  readonly decidedAt: string | null; readonly createdAt: string }
export function reportDocId(reporterId: string, type: ReportTargetType, targetId: string, chatId: string | null): string;
export function parseReportInput(raw: unknown): { type: ReportTargetType; targetId: string; chatId: string | null;
  reason: ReportReason; text: string | null; block: boolean };          // throws invalid_argument

// report_ports.ts
export interface ReportTx {
  getReport(id: string): Promise<Report | null>;
  getTarget(type: ReportTargetType, id: string, chatId: string | null): Promise<ReportTargetView | null>;
  isChatMember(chatId: string, uid: string): Promise<boolean>;
  getQuota(uid: string): Promise<{ day: string; count: number } | null>;
  putReport(r: Report): void;
  putQuota(uid: string, q: { day: string; count: number }): void;
}
export interface ReportStore { runTransaction<T>(fn: (tx: ReportTx) => Promise<T>): Promise<T>;
  list(status: Report['status'], limit: number): Promise<readonly Report[]>; get(id: string): Promise<Report | null>;
  decide(id: string, patch: Pick<Report, 'status' | 'staffNote' | 'decidedBy' | 'decidedAt'>): Promise<void> }
export interface ReportDeps { readonly store: ReportStore; readonly blocks: BlockDeps; readonly clock: Clock }

// report_use_cases.ts
export async function submitReport(deps: ReportDeps, reporterId: string, raw: unknown):
  Promise<{ reportId: string; duplicate: boolean; blocked: boolean }>;
/** `{reportId, status: 'dismissed'|'actioned', note (5–500)}`; staff role checked by the adapter. */
export async function decideReport(deps: ReportDeps, staffId: string, raw: unknown): Promise<Report>;

// Gates (modified)
// Order gate — Done in #198 (`2026-10-08-n1-order-gate.md`): `order_gate.ts` (`OrderGateDeps {providers, blocks?}`,
//   `orderBlocker` → 'not_accepting_orders' | 'blocked' | null, `assertOrderAllowed`), `BookingDeps.blocks: BlockGate`
//   (required), `createBookingDraft` and `createPayment` call `assertOrderAllowed`. This plan does not touch them.
// ChatDeps gains `readonly blocks: BlockGate` — openInquiry: before creating a new chat.
// Chat gains `readonly blockedAt: Date | null`; assertCanSend: blockedAt !== null → DomainError('blocked') (before the read-only check).
// GetContactLinkDeps gains `readonly blocks: BlockGate` — decide(): after the subject/party check → { error: 'blocked' }.
// EventDeps gains `readonly blocks: BlockGate` — registerEvent: host photographer blocked either way → DomainError('blocked').
// memory adapters: MemoryBlockStore (block + index + chats + markers; also implements BlockGate from its records so
// blockUser → gate tests need no second fake), MemoryReportStore. FakeBlockGate is #198's (`fake_block_gate.ts`).
```

### Callables (`asia-southeast1`, `CALLABLE_OPTIONS`)

| Name | Input | Output | Errors |
|---|---|---|---|
| `blockUser` | `{userId, source?: 'menu'\|'report'}` | `{blockedId}` | `unauthenticated`, `invalid_argument`, `not_found`, `limit_exceeded` |
| `unblockUser` | `{userId}` | `{}` | `unauthenticated`, `invalid_argument` |
| `submitReport` | `{targetType, targetId, chatId?, reason, text?, block?: bool}` | `{reportId, duplicate, blocked}` | `unauthenticated`, `invalid_argument`, `not_found`, `permission_denied` (not a chat member), `limit_exceeded` |

Error table: `blocked: 'failed-precondition'` (`details.code: 'blocked'`) — Done in #198 (`2026-10-08-n1-order-gate.md`). CLI `tools/reports.ts`, script `"reports": "tsx tools/reports.ts"`.

### Rules and indexes

```
match /blocks/{blockId} {
  allow get, list: if signedIn() && resource.data.blockerId == request.auth.uid;
  allow write: if false;
}
match /reports/{reportId} { allow read, write: if false; }
// users/{uid}/private/{docId}: unchanged (owner reads `blocks`; `blocks` and `report_quota` are not client-writable)
// chats/{chatId}: client updates must not touch blockedAt (add it to the chat's server-field list if the chat
// update rule lists fields; members/{uid} rule unchanged)
```
Indexes: `blocks (blockerId ASC, createdAt DESC)` (S20.02), `reports (status ASC, createdAt ASC)` (CLI).

### App (Dart)

```dart
// lib/data/safety/safety.dart
@immutable class BlockIndex { const BlockIndex({this.blockedIds = const {}, this.blockedByIds = const {}});
  final Set<String> blockedIds; final Set<String> blockedByIds;
  Set<String> get hidden; bool blockedByMe(String id); bool blockedMe(String id); bool hides(String? id); }
@immutable class BlockedUser { userId, displayName, avatarUrl, blockedAt }
enum ReportTargetType { user, post, message, event }
enum ReportReason { spam('spam'), scam('scam'), harassment('harassment'), inappropriate('inappropriate'),
  stolenPhotos('stolen_photos'), impersonation('impersonation'), other('other'); const ReportReason(this.code); final String code; }
@immutable class ReportTarget { const ReportTarget({required this.type, required this.id, this.chatId, this.ownerId,
  this.ownerName, this.excerpt, this.thumbUrl}); }
  // factories: ReportTarget.user(uid, name), .post(PostSummary, authorName), .message(chatId, messageId, senderId, senderName, text), .event(id, title, hostId?, hostName?)
@immutable class ReportDraft { target, reason, text, block }
@immutable class ReportResult { reportId, duplicate, blocked }
class SafetyError implements Exception { const SafetyError(this.code); final String code; }

// lib/data/safety/safety_repository.dart
abstract class SafetyRepository {
  Stream<BlockIndex> watchIndex();                   // users/{uid}/private/blocks; empty index when missing or signed out
  Future<List<BlockedUser>> blocked({int limit = 50});
  Future<void> block(String userId, {String source = 'menu'});
  Future<void> unblock(String userId);
  Future<ReportResult> report(ReportDraft draft);
}
// firestore_safety_repository.dart: FirestoreSafetyRepository({required String? uid, FirebaseFirestore? db, FirebaseFunctions? functions})
// safety_providers.dart
final safetyRepositoryProvider = Provider<SafetyRepository>(...);       // rebuilt on uid change
final blockIndexProvider = StreamProvider<BlockIndex>(...);            // one listener per session
final hiddenUsersProvider = Provider<Set<String>>((ref) => ref.watch(blockIndexProvider).value?.hidden ?? const {});

// ChatThread gains `final DateTime? blockedAt`; ChatErrorCode gains `blocked`;
// EventError('blocked') handled by the register sheet.
// BookingErrorCode.blocked and its booking-sheet / S04.04 copy: Done in #198 (`2026-10-08-n1-order-gate.md`).

// lib/features/safety/
Future<ReportResult?> showReportSheet(BuildContext context, {required ReportTarget target});           // S20.01
Future<void> showSafetyMenu(BuildContext context, WidgetRef ref, {required ReportTarget target,
  String? blockUserId, String? blockName, VoidCallback? onShare});                                     // shared "…" sheet
Future<bool> confirmBlock(BuildContext context, WidgetRef ref, {required String userId, required String name});
Future<bool> confirmUnblock(BuildContext context, WidgetRef ref, {required String userId, required String name});
class BlockedUsersScreen extends ConsumerWidget {}                                                     // S20.02, /settings/blocked
class BlockedProfileView extends ConsumerWidget { const BlockedProfileView({required String uid, required String name, required bool byMe}); }
```
Routes: `/settings/blocked` (`ScreenCodes.blockedUsers`). The sheet has no route (`/report` in §2 becomes "— (sheet)"). New icon `AppIcons.block = Symbols.block`.

### Strings (`app_vi.arb`, exact)

Menu: `safetyMore` "Thêm tuỳ chọn"; `safetyShareProfile` "Chia sẻ hồ sơ"; `safetyLinkCopied` "Đã sao chép liên kết hồ sơ"; `safetyReport` "Báo cáo"; `safetyReportPost` "Báo cáo bài viết"; `safetyReportMessage` "Báo cáo tin nhắn"; `safetyReportEvent` "Báo cáo sự kiện"; `safetyReportUser` "Báo cáo {name}"; `safetyBlock` "Chặn {name}"; `safetyUnblock` "Bỏ chặn {name}".
S20.01: `reportTitleUser` "Báo cáo {name}"; `reportTitlePost` "Báo cáo bài viết"; `reportTitleMessage` "Báo cáo tin nhắn"; `reportTitleEvent` "Báo cáo sự kiện"; `reportAnonymous` "Người bị báo cáo không biết ai đã báo cáo."; `reportReasonTitle` "Vì sao bạn báo cáo?"; `reportReasonSpam` "Spam hoặc quảng cáo"; `reportReasonScam` "Lừa đảo, đòi chuyển tiền ngoài ứng dụng"; `reportReasonHarassment` "Quấy rối hoặc xúc phạm"; `reportReasonInappropriate` "Nội dung nhạy cảm, không phù hợp"; `reportReasonStolen` "Ảnh lấy cắp, vi phạm bản quyền"; `reportReasonImpersonation` "Giả mạo người khác"; `reportReasonOther` "Lý do khác"; `reportTextLabel` "Mô tả thêm (tuỳ chọn)"; `reportTextRequired` "Lý do khác cần mô tả ít nhất 10 ký tự"; `reportBlockAlso` "Chặn {name}"; `reportBlockAlsoBody` "Hai bên không thấy bài của nhau, không nhắn tin hay đặt lịch với nhau."; `reportSubmit` "Gửi báo cáo"; `reportSent` "Đã gửi báo cáo. Cảm ơn bạn."; `reportSentBlocked` "Đã gửi báo cáo và chặn {name}."; `reportDuplicate` "Bạn đã báo cáo nội dung này rồi."; `reportLimit` "Bạn đã gửi nhiều báo cáo hôm nay. Thử lại ngày mai."; `reportFailed` "Chưa gửi được. Thử lại."
Block: `blockConfirmTitle` "Chặn {name}?"; `blockConfirmBody` "Hai bên sẽ không thấy bài của nhau, không nhắn tin hay đặt lịch với nhau. Buổi chụp đã đặt vẫn giữ; cần trao đổi thì liên hệ hỗ trợ. {name} không nhận thông báo."; `blockConfirm` "Chặn"; `blockKeep` "Không chặn"; `blockDone` "Đã chặn {name}"; `blockFailed` "Chưa chặn được. Thử lại."; `blockLimit` "Bạn đã chặn quá nhiều người. Bỏ chặn bớt rồi thử lại."; `unblockConfirmTitle` "Bỏ chặn {name}?"; `unblockConfirmBody` "Hai bên lại thấy bài của nhau, nhắn tin và đặt lịch được."; `unblockConfirm` "Bỏ chặn"; `unblockKeep` "Giữ chặn"; `unblockDone` "Đã bỏ chặn {name}".
S20.02: `blockedTitle` "Người đã chặn"; `blockedNote` "Người bạn chặn không thấy bài của bạn, không nhắn tin hay đặt lịch với bạn. Họ không nhận thông báo."; `blockedSince` "Chặn {date}"; `blockedUnblock` "Bỏ chặn"; `blockedEmptyTitle` "Bạn chưa chặn ai"; `blockedEmptyBody` "Chặn từ menu … trên hồ sơ, bài viết hoặc tin nhắn."; `settingsBlocked` "Người đã chặn"; `settingsBlockedBody` "Xem và bỏ chặn".
Blocked states: `profileBlockedByMeTitle` "Bạn đã chặn {name}"; `profileBlockedByMeBody` "Bỏ chặn để xem hồ sơ, nhắn tin và đặt lịch."; `profileBlockedByThemTitle` "Không xem được hồ sơ này"; `profileBlockedByThemBody` "Hồ sơ này không hiển thị với bạn."; `postHiddenTitle` "Không xem được bài này"; `postHiddenBody` "Bài này không hiển thị với bạn."; `chatBlockedByMe` "Bạn đã chặn {name}. Bỏ chặn để nhắn tin."; `chatBlocked` "Không gửi được tin nhắn trong cuộc trò chuyện này."; `chatMessageRemoved` "Tin nhắn đã bị gỡ"; `bookingBlockedNote` "Hai bên đã chặn nhau. Cần trao đổi về buổi chụp, hãy liên hệ hỗ trợ."; (`bookingErrBlocked` "Không đặt lịch được với người này.": Done in #198, reuse the key); `eventErrBlocked` "Bạn không đăng ký được sự kiện này."; `chatErrBlocked` "Không gửi được: hai bên đã chặn nhau."
`timelineReportSoon` is deleted (no longer used).

## Review Focus

1. **A block that a booking update erases.** `syncBookingChat` rewrites the chat with `toFirestoreChat(chat)`; without `blockedAt` in the domain `Chat` and both mappings, the first booking status change after a block reopens the chat. Pinned by Task 3 (the shared `chat round-trips every field` test of #131, extended with `blockedAt`) and Task 2 `booking chat sync keeps blockedAt`.
2. **Booking or inquiry around the UI.** A client that ignores the hidden profile can still call `createBooking` / `openInquiry` / `getContactLink` / `registerEvent`: each must answer `blocked`, in both directions. `createBooking`/`createPayment` are pinned by #198 (gate and `FirestoreBlockGate` tests); here the rest by Task 2 tests (`openInquiry …`, `getContactLink …`, `registerEvent …` in both directions) and, end to end with documents written by `blockUser`, by the Task 3 integration test.
3. **Unblock reopens too much.** If both blocked each other, one unblock must leave the chat closed and both still hidden from each other. Pinned by Task 2 `mutual block: one unblock keeps the chat blocked`.
4. **Report privacy and abuse.** Nobody reads `reports` from the client; the reported user cannot learn the reporter; the same target reported twice stays one report; the 21st report of the day is refused; a message can be reported only by a member of its chat. Pinned by Task 3 rules tests and Task 2 `submitReport` tests.
5. **Hidden both ways.** The person who was blocked must also stop seeing the blocker's posts (the index carries `blockedByIds`), and the hidden set must update live when either side blocks/unblocks. Pinned by Task 6 `a post by someone who blocked me is not in the feed` and `unblocking shows their posts again without restart`.

## Chi phí Google

Unit prices (cost spec): Firestore $0.06/100K reads, $0.18/100K writes (nam5 upper bound, **chưa xác nhận** for Singapore). **Functions (one rule for every plan, cost spec §12):** at (b) new invocations and CPU fit the free tier (2M invocations, 180,000 vCPU-s, 360,000 GiB-s per month) → $0; at (c) the app already uses the free tier up (§12 (c): 2.5M invocations, ~500K vCPU-s), so this plan's Functions work is charged at Tier 2: $0.40/M invocations, $0.0000336/vCPU-s, $0.0000035/GiB-s. Assumptions: 20 sessions/MAU/month; 0.5% of MAU block someone per month, 1% report something; 300 (b) / 3,000 (c) bookings, 1,000 / 10,000 inquiries, 1,500 / 15,000 contact-link calls, 100 / 1,000 paid registrations.

| Action | Reads | Writes | Notes |
|---|---|---|---|
| App session (block index) | 1 (+1 per change) | 0 | one listener on `users/{uid}/private/blocks` |
| `openInquiry` (new chat), `getContactLink`, `registerEvent` | +2 each | 0 | `getAll` of the two block documents (`createBooking`/`createPayment` gate reads are counted in #198's plan) |
| `sendMessage` | +0 | 0 | the flag is on the chat document already read |
| `blockUser` / `unblockUser` | ~6 (block, 2 indexes, 2 chats, profile) | ~8 (block, 2 indexes, ≤ 2 chats, ≤ 4 marker deletes) | |
| `submitReport` | ~4 (report, target, membership, quota) | 2 (+ block) | |
| Open S20.02 | ≤ 50 (`get`, `limit(50)`) | 0 | rare |

New functions: 3 callables, 256 MiB, < 0.3 s. Calls/month: (b) block/unblock ≈ 5 + report 10 → ~15; (c) ~150 (≈ 45 vCPU-s, < $0.01 under the Functions rule). No trigger, no scheduled job, no Storage path, no paid API.

Reads/month: (b) sessions 20K + gates (1,000 + 1,500 + 100) × 2 ≈ 5.2K + callables < 200 → ≈ 25K → **$0.015**; (c) ≈ 254K → **$0.15**. Writes negligible (< 300 at (c), $0.001).

**Conclusion:** adds about **$0.02/month at (b)** and **$0.15/month at (c)**; under $5, no mitigation needed.

## Tasks

### Task 1: Mock frames, mock edits, screen codes and screen spec

**Files:**
- Modify: `docs/design/ui-mock.html` (new section `<h2 id="S20">` before `<h2 id="S24">`, after the S18/S19 sections if present; `#S03.01` hero and caption; `#S11.02` hero; captions of `#S02.02`, `#S07.01`, `#S11.05`, `#S11.06`, `#S24.01`, `#S09.02`; code table; progress table), `docs/superpowers/specs/2026-10-01-remaining-screens.md` (§2 S20 rows: S20.01 route "— (sheet)", status; §3i.3 paragraph), `docs/superpowers/specs/screens/README.md`
- Create: `docs/superpowers/specs/screens/report-block.md`
- Check only: `app_flutter/lib/core/screen_codes.dart`

**Interfaces:** Produces frame ids `S20.01-menu`, `S20.01`, `S20.01-message`, `S20.02`, `S03.01-blocked`, `S07.01-blocked`.

- [ ] **Step 1:** Section head, verbatim:
  ```html
  <h2 id="S20">S20 · Báo cáo & chặn</h2>
  <p>Báo cáo người dùng, bài, tin nhắn hoặc sự kiện bằng một sheet chung; chặn để hai bên không thấy nhau, không nhắn tin và không đặt lịch với nhau. Booking đã có vẫn giữ.</p>
  <div class="rail">
  ```
  Frames start with the usual `.sb`. Sheets use `<div class="dim"></div><div class="sheet"><div class="grab"></div>…</div>` and a close icon row like `#S22.04`.
- [ ] **Step 2: `S20.01-menu`** (`data-code="S20.01"`): background = the `#S03.01` hero block (`scr hb`, `ph p1` 4:3 with back `ic dk` and `<div style="position:absolute;top:30px;right:10px" class="ic dk" role="button" tabindex="0" aria-label="Thêm tuỳ chọn"><span class="ms">more_horiz</span></div>`, the name row "Minh Trí" + `vf`, meta "Chân dung · Cặp đôi · Quận 3"); sheet content: `<div class="card" style="flex-direction:column;align-items:stretch;padding:2px 12px;gap:0">` with three `.irow2` rows: `<span class="ms">ios_share</span><div class="grow"><b>Chia sẻ hồ sơ</b></div>`, `<span class="ms">flag</span><div class="grow"><b>Báo cáo</b></div>`, `<span class="ms" style="color:var(--bad)">block</span><div class="grow"><b style="color:var(--bad)">Chặn Minh Trí</b></div>`. Cap: `<span class="n new">Mới</span><span class="n">S20.01 · Menu "…"</span><b>Báo cáo và chặn ở cùng một chỗ trên mọi màn</b><span>Hồ sơ (S03.01, thay nút chia sẻ: "Chia sẻ hồ sơ", "Báo cáo", "Chặn {tên}"), bài (S02.02: "Báo cáo bài viết", "Chặn {tên}"), tin nhắn (nhấn giữ ở S07.01, S11.06: "Báo cáo tin nhắn", "Chặn {tên}"), timeline (S11.05: "Báo cáo bài viết"), sự kiện (S11.02: "Báo cáo sự kiện"), album (S24.01: "Báo cáo {tên}"). Đã chặn thì dòng thành "Bỏ chặn {tên}". "Chặn" mở sheet xác nhận có nút đỏ.</span>`
- [ ] **Step 3: `S20.01`** (report a user, over the same background): sheet:
  ```html
  <div class="row" style="justify-content:space-between"><div class="h3">Báo cáo Minh Trí</div><div class="ic" role="button" tabindex="0" aria-label="Đóng"><span class="ms">close</span></div></div>
  <div class="meta">Người bị báo cáo không biết ai đã báo cáo.</div>
  <b style="font-size:13px">Vì sao bạn báo cáo?</b>
  <div class="optc" role="radiogroup" style="gap:5px">
    <div class="opt" role="radio" aria-checked="false" style="padding:7px 12px"><span class="grow">Spam hoặc quảng cáo</span></div>
    <div class="opt on" role="radio" aria-checked="true" style="padding:7px 12px"><span class="grow">Lừa đảo, đòi chuyển tiền ngoài ứng dụng</span><span class="ms" style="color:var(--accent)">check</span></div>
    <div class="opt" role="radio" aria-checked="false" style="padding:7px 12px"><span class="grow">Quấy rối hoặc xúc phạm</span></div>
    <div class="opt" role="radio" aria-checked="false" style="padding:7px 12px"><span class="grow">Nội dung nhạy cảm, không phù hợp</span></div>
    <div class="opt" role="radio" aria-checked="false" style="padding:7px 12px"><span class="grow">Ảnh lấy cắp, vi phạm bản quyền</span></div>
    <div class="opt" role="radio" aria-checked="false" style="padding:7px 12px"><span class="grow">Giả mạo người khác</span></div>
    <div class="opt" role="radio" aria-checked="false" style="padding:7px 12px"><span class="grow">Lý do khác</span></div>
  </div>
  <div class="field" style="min-height:48px"><small>Mô tả thêm (tuỳ chọn)</small>Nhắn qua Zalo bảo chuyển khoản trước 500k để giữ lịch.</div>
  <div class="chk"><i class="on"></i><span><b>Chặn Minh Trí</b><br>Hai bên không thấy bài của nhau, không nhắn tin hay đặt lịch với nhau.</span></div>
  <div class="btn pri">Gửi báo cáo</div>
  ```
  Cap: `<span class="n new">Mới</span><span class="n">S20.01 · Báo cáo (sheet)</span><b>Một lý do, vài chữ, chặn luôn nếu muốn</b><span>Sheet dùng chung cho người dùng, bài, tin nhắn, sự kiện; tiêu đề đổi theo đối tượng: "Báo cáo {tên}", "Báo cáo bài viết", "Báo cáo tin nhắn", "Báo cáo sự kiện". Bảy lý do cố định; "Lý do khác" cần mô tả ít nhất 10 ký tự. "Chặn {tên}" không có với sự kiện do ứng dụng tổ chức. Gửi xong: "Đã gửi báo cáo. Cảm ơn bạn." Báo cáo lại cùng nội dung: "Bạn đã báo cáo nội dung này rồi." Đội hỗ trợ xem ở hàng đợi nội bộ (S23.05).</span>`
- [ ] **Step 4: `S20.01-message`** (`data-code="S20.01"`): background = `#S07.01` bar ("Minh Trí") and two bubbles: `<div class="bub you">Chị chuyển khoản trước 500k qua số này để em giữ lịch nhé.</div>` and `<div class="bub me">Mình thanh toán trong app được không anh?</div>`; sheet: h3 "Báo cáo tin nhắn" + close; `<div class="esc"><span class="ms">format_quote</span><span><b>Minh Trí</b><br>Chị chuyển khoản trước 500k qua số này để em giữ lịch nhé.</span></div>`; "Vì sao bạn báo cáo?"; the same seven `.opt` rows with "Lừa đảo, đòi chuyển tiền ngoài ứng dụng" on; `<div class="field" style="min-height:40px"><small>Mô tả thêm (tuỳ chọn)</small><span style="color:var(--ink-3)">Không bắt buộc</span></div>`; the `.chk` (unchecked: `<i></i>`) "Chặn Minh Trí" with the same body; `btn pri` "Gửi báo cáo". Cap: `<span class="n new">Mới</span><span class="n">S20.01 · Báo cáo tin nhắn</span><b>Trích nguyên văn tin bị báo cáo</b><span>Nhấn giữ tin của người khác ở S07.01 hoặc S11.06. Đội hỗ trợ nhận bản sao tin nhắn lúc báo cáo, kể cả khi người gửi xoá sau đó.</span>`
- [ ] **Step 5: `S20.02`**: `.bar` (back · "Người đã chặn" · invisible ic); meta "Người bạn chặn không thấy bài của bạn, không nhắn tin hay đặt lịch với bạn. Họ không nhận thông báo."; card with three `.irow2` rows: `<span class="av m" style="background:var(--p4)"></span><div class="grow"><b>Quang Huy</b><span class="meta">Chặn 12/10</span></div><div class="btn out xs" style="padding:0 10px">Bỏ chặn</div>`, "Thu Hà" "Chặn 03/10" (`--p6`), "Bảo Anh" "Chặn 21/9" (`--p2`). Cap: `<span class="n new">Mới</span><span class="n">S20.02 · Người đã chặn</span><b>Bỏ chặn khi đổi ý</b><span><code>/settings/blocked</code>, mở từ Cài đặt (Tài khoản → Người đã chặn). Mới chặn trước. "Bỏ chặn" mở sheet xác nhận (không đỏ); xong thì hàng biến mất. Trống: "Bạn chưa chặn ai" / "Chặn từ menu … trên hồ sơ, bài viết hoặc tin nhắn."</span>`
- [ ] **Step 6: `S03.01-blocked`** (`data-code="S03.01"`): `.body`: `.bar` (back · empty title · `more_horiz`), then `<div class="empty"><div class="ill" style="display:flex;align-items:center;justify-content:center;color:var(--ink-3)"><span class="ms" style="font-size:40px">block</span></div><b>Bạn đã chặn Minh Trí</b><span>Bỏ chặn để xem hồ sơ, nhắn tin và đặt lịch.</span><div class="btn out sm" style="width:auto;padding:0 18px">Bỏ chặn</div></div>`. Cap: `<span class="n new">Mới</span><span class="n">S03.01 · Đã chặn</span><b>Không hiện hồ sơ của người đã chặn</b><span>Bạn chặn họ: như trên, "Bỏ chặn" mở sheet xác nhận. Họ chặn bạn: "Không xem được hồ sơ này" / "Hồ sơ này không hiển thị với bạn.", không có nút. Tương tự ở S02.02: "Không xem được bài này".</span>`
- [ ] **Step 7: `S07.01-blocked`** (`data-code="S07.01"`): `#S07.01` bar, `.ctx` card and the first two bubbles; instead of the composer row: `<div class="esc" style="margin-bottom:8px"><span class="ms">block</span><span class="grow">Bạn đã chặn Minh Trí. Bỏ chặn để nhắn tin.</span><span class="tlink" style="padding:0">Bỏ chặn</span></div>`. Cap: `<span class="n new">Mới</span><span class="n">S07.01 · Đã chặn</span><b>Đọc được, không gửi được</b><span>Tin cũ vẫn đọc được. Người bị chặn thấy "Không gửi được tin nhắn trong cuộc trò chuyện này." (không có "Bỏ chặn"). Buổi chụp đã đặt vẫn giữ; S05.02 ẩn Nhắn tin và Liên hệ, ghi "Hai bên đã chặn nhau. Cần trao đổi về buổi chụp, hãy liên hệ hỗ trợ."</span>`
- [ ] **Step 8: Edits to existing frames.** `#S03.01`: replace the hero's `ios_share` icon with `more_horiz` (`aria-label="Thêm tuỳ chọn"`); caption: append "Nút "…" (khách xem, mọi biến thể S03.01): Chia sẻ hồ sơ, Báo cáo, Chặn (S20.01)." `#S11.02`: add `<div style="position:absolute;top:30px;right:54px" class="ic dk" role="button" tabindex="0" aria-label="Thêm tuỳ chọn"><span class="ms">more_horiz</span></div>` beside the share icon; caption: append ""…" → Báo cáo sự kiện (S20.01)." Captions: `#S02.02` append ""…" → Báo cáo bài viết, Chặn {tên} (S20.01)."; `#S07.01` append ""…" → Báo cáo, Chặn {tên}; nhấn giữ tin của người kia → Báo cáo tin nhắn (S20.01)."; `#S11.05` append "Menu của bài: Báo cáo bài viết (S20.01)."; `#S11.06` append "Nhấn giữ tin của người khác → Báo cáo tin nhắn, Chặn {tên} (S20.01)."; `#S24.01` append "Khách xem: "…" → Báo cáo {tên} (S20.01)."; `#S09.02` append "Tài khoản: Người đã chặn (S20.02)." Code table: S20.01, S20.02 → "Có". Progress table: `<tr><td>Báo cáo & chặn</td><td>S20.01, S20.02, S03.01 đã chặn, S07.01 đã chặn, menu "…" ở S02.02, S03.01, S07.01, S11.02, S11.05, S11.06, S24.01</td><td>Có mock, có plan (#144)</td></tr>`. The code-table line is also edited by #142/#143: on a rebase conflict re-apply only the S20 cells. If #143 already added the bookmark to `#S03.01`, keep it.
- [ ] **Step 9:** Spec §2: S20.01 route "— (sheet)", status cells "⬜ có mock, có plan (#144)"; §3i.3: paragraph "Đã chốt khi viết plan #144" (Decisions 2, 5, 6, 10) and §8 question 24 "đề xuất giữ như spec (plan #144)". Create `screens/report-block.md` (README template, S20.01, S20.02, blocked states; strings of the Contract) + index row.
- [ ] **Step 10:** Parse check (`python3 -c "import html.parser; html.parser.HTMLParser().feed(open('docs/design/ui-mock.html').read())"`; balanced `div`s in the new section).
- [ ] **Step 11: Commit** `docs(mock): S20 report sheet, blocked users and blocked states [#144]`.

### Task 2: Domain — blocks, reports and the block gates

**Files:**
- Create: `packages/domain/src/block.ts`, `block_ports.ts`, `block_use_cases.ts`, `memory_block_store.ts`, `report.ts`, `report_ports.ts`, `report_use_cases.ts`, `memory_report_store.ts`; tests `packages/domain/test/block.test.ts`, `block_use_cases.test.ts`, `report_use_cases.test.ts`, `test/support/safety_world.ts`
- Modify: `block_ports.ts` (#198's file: add `BlockTx`, `BlockStore`, `PublicProfiles`, `BlockDeps` beside `BlockGate`/`blockDocId`), `chat.ts` (`Chat.blockedAt`, `assertCanSend`), `chat_ports.ts` (`ChatDeps.blocks`), `open_inquiry.ts`, `booking_chat_sync.ts` (carry `blockedAt` from the existing chat when it builds the next one), `get_contact_link.ts` (`GetContactLinkDeps.blocks`), `event_ports.ts` (`EventDeps.blocks`), `event_registration.ts`, `memory_chat_store.ts` (if it builds chats), `index.ts`; test worlds `chat_world.ts`, `event_world.ts`, `event_social_world.ts` (add an open `FakeBlockGate` from #198; `booking_world.ts` already has one), tests `open_inquiry.test.ts`, `send_message.test.ts`, `booking_chat_sync.test.ts`, `get_contact_link.test.ts`, `event_registration.test.ts`. Not touched (Done in #198 (`2026-10-08-n1-order-gate.md`)): `errors.ts`, `order_gate.ts`, `booking_ports.ts`, `create_booking.ts`, `create_payment.ts`, `fake_block_gate.ts`.

**Interfaces:** Produces the domain contract. Consumes #198's `BlockGate`, `blockDocId`, `FakeBlockGate`, `DomainError('blocked')`; `chatIdFor`, `graphemeCount`, `DomainError`, `moderateEventTimeline` (not here; CLI).

- [ ] **Step 1:** Contract check (domain bullets, including #198's names in `block_ports.ts`, `order_gate.ts`, `fake_block_gate.ts`); ledger differences. Do not re-create or move the order gate.
- [ ] **Step 2: Failing tests.** `block.test.ts`: `withBlock/withoutBlock keep set semantics`; `blockedEitherWay checks both arrays`. (Order-gate tests for `orderBlocker`, `assertOrderAllowed`, `createBookingDraft` and `createPayment`: Done in #198 (`2026-10-08-n1-order-gate.md`).) `block_use_cases.test.ts`: `MemoryBlockStore as a BlockGate sees a block written by blockUser and forgets it after unblockUser`; `block writes the record with name and avatar, both indexes, and blockedAt on both existing chat orientations`; `block deletes follows and saved-photographer markers both ways`; `blocking twice changes nothing`; `blocking yourself → invalid_argument; an unknown user → not_found`; `the 501st block → limit_exceeded`; `unblock removes the record and both index entries and clears blockedAt`; `mutual block: one unblock keeps the chat blocked and both still hidden`; `unblocking someone not blocked is a no-op`. `report_use_cases.test.ts`: `a user report stores the snapshot name`; `a post report stores the caption excerpt (≤ 300) and the first image, owner = authorId`; `a message report requires chat membership (permission_denied) and refuses system messages`; `an event report on a platform event ignores block: true`; `reporting your own post → invalid_argument`; `other without 10 characters → invalid_argument`; `same reporter and target twice → duplicate true, one document`; `the 21st report on one Vietnam day → limit_exceeded; the count restarts the next day`; `block: true blocks the owner with source report and returns blocked true`; `decideReport writes status, note, decidedBy, decidedAt; a note under 5 characters → invalid_argument`. Gates (the order gate is #198's; these are the non-order paths): `openInquiry refused for a new chat between a blocked pair; an existing chat id is still returned`; `sendMessage on a chat with blockedAt → blocked (before read-only)`; `booking chat sync keeps blockedAt`; `getContactLink → blocked and logs not granted`; `registerEvent refused when the host photographer is blocked either way; platform events unaffected`.
- [ ] **Step 3:** Run `cd packages/domain && npm test`; new tests fail.
- [ ] **Step 4: Implement.** The block transaction (read everything, then write):
  ```ts
  export async function blockUser(deps: BlockDeps, callerId: string, raw: unknown): Promise<BlockRecord> {
    const { userId, source } = parseBlockInput(raw, callerId);           // invalid_argument for self / malformed
    const profile = await deps.profiles.get(userId);
    if (!profile) throw new DomainError('not_found');
    const at = deps.clock.now().toISOString();
    return deps.store.runTransaction(async (tx) => {
      const existing = await tx.getBlock(callerId, userId);
      const mine = await tx.getIndex(callerId);
      const theirs = await tx.getIndex(userId);
      const chats = [chatIdFor(callerId, userId), chatIdFor(userId, callerId)];
      const exists = await Promise.all(chats.map((c) => tx.chatExists(c)));
      if (existing) return existing;
      if (mine.blockedIds.length >= MAX_BLOCKS) throw new DomainError('limit_exceeded');
      const rec: BlockRecord = { blockerId: callerId, blockedId: userId, blockedName: profile.name,
        blockedAvatarUrl: profile.avatarUrl, source, createdAt: at };
      tx.putBlock(rec);
      tx.putIndex(callerId, withBlock(mine, userId, 'blocked'), at);
      tx.putIndex(userId, withBlock(theirs, callerId, 'blockedBy'), at);
      chats.forEach((c, i) => { if (exists[i]) tx.setChatBlockedAt(c, at); });
      tx.deleteFollowMarkers(callerId, userId);
      return rec;
    });
  }
  ```
  `unblockUser` mirrors it; it clears `blockedAt` only when `!blockedEitherWay(withoutBlock(mine, userId, 'blocked'), userId)`. Report quota day = the Vietnam calendar day (UTC+7, `yyyy-MM-dd`, the helper events use for `dayKey`). Update every deps literal the compiler flags (open `FakeBlockGate` from #198).
- [ ] **Step 5:** `npm test && npm run typecheck && npm run lint` green (incl. `purity.test.ts`).
- [ ] **Step 6: Commit** `feat(domain): blocks with server gates on chat, contact and events; reports [#144]`.

### Task 3: Functions — adapters, callables, chat mapping, rules, indexes, seed, staff CLI

**Files:**
- Create: `app_flutter/firebase/functions/src/callables/safety.ts` (`handleBlockUser`, `handleUnblockUser`, `handleSubmitReport`), `tools/reports.ts`; tests `test/unit/safety_callables.test.ts`, `reports_cli.test.ts`; integration `test/integration/block.test.ts` (written, not run)
- Modify: `src/infra/safety_firestore.ts` (#198's file with `FirestoreBlockGate`: add `FirestoreBlockStore`, `FirestoreReportStore`, `FirestorePublicProfiles`; block paths through `blockDocId`), `src/infra/live_safety.ts` (#198's file with `liveBlockGate()`: add `liveBlockDeps()`, `liveReportDeps()`), `test/unit/safety_firestore.test.ts` (#198's file: add the store mapping tests), `src/index.ts` (three exports), `src/infra/chat_firestore.ts` (`blockedAt` both ways), `live_chat.ts`, `live.ts` (contact), `live_event.ts` (`blocks: liveBlockGate()`), `package.json` (`reports` script), `seed/fixtures.ts`, `seed/README.md`, tests that build these deps (`event_payment_callables.test.ts` (its `EventDeps`), `event_callables.test.ts`, `chat_callables.test.ts`, `get_contact_link_handler.test.ts`), `test/unit/chat_firestore.test.ts`, `seed_fixtures.test.ts`; `app_flutter/firebase/firestore.rules`, `firestore.indexes.json`, `rules-test/rules.test.mjs`. Not touched (Done in #198 (`2026-10-08-n1-order-gate.md`)): `src/callables/errors.ts` + `errors.test.ts` (`blocked`), `src/infra/live_booking.ts` (`blocks: liveBlockGate()`), the `BookingDeps` literals in `booking_callables.test.ts`, `booking_clock_ticket_release.test.ts`, `support/payment_world.ts`.

**Interfaces:** Consumes the domain contract and #198's `FirestoreBlockGate` / `liveBlockGate()` (one `getAll` of `blocks/{a}_{b}` and `blocks/{b}_{a}`; the documents this plan's `blockUser` writes must use exactly that path). `FirestoreBlockStore.deleteFollowMarkers` deletes `follows/{a}_{b}`, `follows/{b}_{a}`, `savedPhotographers/{a}_{b}`, `savedPhotographers/{b}_{a}`. `takedown` (CLI, Decision 10) uses the Admin SDK and, for event posts, `moderateEventTimeline` through `liveTimelineDeps()`.

- [ ] **Step 1:** Contract check (live deps files, chat mapping, chat update rule). If #131 (S07) already changed `toFirestoreChat` (adds `bookingStatus`), add `blockedAt` beside it.
- [ ] **Step 2: Failing tests.** `safety_callables.test.ts`: `blockUser without auth → unauthenticated`; `returns {blockedId}`; `limit_exceeded → resource-exhausted`; `submitReport maps permission_denied for a non-member`; `returns duplicate true on the second call`. (`blocked maps to failed-precondition`: Done in #198.) `chat_firestore.test.ts`: extend the shared `chat round-trips every field` test (created by #131) with `blockedAt` (null and a date). `safety_firestore.test.ts` (extend #198's file): `block record and index mapping`; `blockUser writes the record at the path FirestoreBlockGate reads` (`blocks/{blockerId}_{blockedId}`); `report mapping keeps the snapshot`. `reports_cli.test.ts`: `parseArgs list/show/dismiss/takedown`; `dismiss and takedown need a note and --actor`; `takedown of an event target prints the S12.03 instruction and changes nothing`. `seed_fixtures.test.ts`: `Minh has blocked Bình (record and both indexes)`; `one open report by Lan on seed-post-an-5`.
  Rules tests (written, not run): `a user lists their own blocks`; `a user cannot read blocks made by others (including against them)`; `nobody reads or writes reports`; `the owner reads private/blocks but cannot write it`; `a client cannot write private/report_quota`; `a chat member cannot set blockedAt`.
  Integration (written, not run): `after a block, createBooking and sendMessage answer failed-precondition blocked in both directions; after unblock they work` (createBooking's refusal comes from #198's gate reading the documents `blockUser` wrote).
- [ ] **Step 3:** `npm test` (functions); the new tests fail.
- [ ] **Step 4: Implement.** Rules and the two indexes per Contract. Seed: Minh blocks Bình (`source: 'menu'`), the open report; README rows ("Minh và Bình đã chặn nhau: Minh không thấy bài của Bình, Bình không mở được hồ sơ của Minh") and a "Staff CLI for reports" note.
- [ ] **Step 5:** `npm test && npm run build` (functions) and domain `npm test` green. Ledger: rules/integration tests written, not run; the self-hosted `services/api` contact-link route has no block check (Deferred).
- [ ] **Step 6: Commit** `feat(functions): blockUser, unblockUser, submitReport, chat blockedAt, reports CLI [#144]`.

### Task 4: App data — safety repository, block index, error codes

**Files:**
- Create: `app_flutter/lib/data/safety/safety.dart`, `safety_repository.dart`, `firestore_safety_repository.dart`, `safety_providers.dart`; `test/support/fake_safety_repository.dart`; tests `test/data/safety/safety_mapping_test.dart`, `safety_repository_test.dart`
- Modify: `lib/data/chat/chat.dart` (`ChatThread.blockedAt`), `firestore_chat_repository.dart` (map it; `blocked` → `ChatErrorCode.blocked`), `chat_repository.dart` (`ChatErrorCode.blocked`), `test/support/fake_chat_repository.dart`, `lib/core/theme/app_icons.dart` (`block`), their tests. (`BookingErrorCode.blocked` in `_codeToBookingError`: Done in #198 (`2026-10-08-n1-order-gate.md`).)

**Interfaces:** Produces the Dart contract (`lib/data/safety/*`, `hiddenUsersProvider`). Callable errors: `details.code` → `SafetyError(code)`, `unavailable|deadline-exceeded` → `'network'`.

**Backend wiring:** listener on `users/{uid}/private/blocks` (owner read), `get` of `blocks where blockerId == uid orderBy createdAt desc limit 50`, callables `blockUser`, `unblockUser`, `submitReport`.

- [ ] **Step 1:** Contract check (chat/booking error enums, ChatThread mapping).
- [ ] **Step 2: Failing tests:** `BlockIndex.hidden is the union; hides(null) is false`; `watchIndex emits an empty index for a missing document and for signed-out`; `blocked() maps name, avatar and blockedAt`; `report() sends targetType, targetId, chatId, reason code, trimmed text and block`; `report() maps limit_exceeded to SafetyError('limit_exceeded')`; `ChatThread maps blockedAt`; `send failing with blocked maps to ChatErrorCode.blocked`; `ReportTarget.post uses authorId as owner and the first image as thumb`.
- [ ] **Step 3:** Run `test/data/safety`, `test/data/chat`; new tests fail.
- [ ] **Step 4: Implement.**
- [ ] **Step 5:** `flutter analyze` clean; the two folders green.
- [ ] **Step 6: Commit** `feat(data): safety repository, live block index, blocked error codes [#144]`.

### Task 5: S20.01 report sheet and the "…" entries

**Files:**
- Create: `app_flutter/lib/features/safety/report_sheet.dart`, `report_controller.dart`, `safety_menu.dart`, `block_confirm.dart`; tests `test/features/safety/report_sheet_test.dart`, `safety_menu_test.dart`
- Modify: `lib/features/photographer_profile/photographer_profile_screen.dart` (visitor "…" in the AppBar, `Key('profile-more')`), `lib/features/photo/photo_detail_screen.dart` (hero "…", `Key('photo-more')`, not for own posts), `lib/features/chat/chat_screen.dart` (AppBar "…" always: existing items + report/block; long-press on the other person's messages → "Báo cáo tin nhắn"; render `deletedAt` as "Tin nhắn đã bị gỡ"), `lib/features/event_chat/event_chat_screen.dart` (long-press menu for every member on others' messages: moderators keep pin/delete first, then "Báo cáo tin nhắn", "Chặn {name}"), `lib/features/events/timeline_tab.dart` (`Key('timeline-report')` enabled → "Báo cáo bài viết" for posts not by me; remove `trailing: l.timelineReportSoon`), `lib/features/events/event_screen.dart` (`_Cover` gains `onMore` → "Báo cáo sự kiện"), `lib/features/album/album_detail_screen.dart` (visitor "…" → "Báo cáo {name}"), `lib/l10n/app_vi.arb` (S20.01, menu, block strings; delete `timelineReportSoon`); tests in the matching `test/features/**` folders

**Interfaces:** Consumes `SafetyRepository`, `blockIndexProvider`. Produces `showReportSheet`, `showSafetyMenu`, `confirmBlock`, `confirmUnblock` (Contract). `ReportController` (AutoDispose): `reason`, `text`, `block` (default false), `submitting`, `error`; `submit()` → `ReportResult`.

**Backend wiring:** `submitReport` (with `block`), `blockUser`, `unblockUser` callables; no Firestore read except the live block index (to show "Chặn" vs "Bỏ chặn").

**Mock parity:** `#S20.01-menu` (rows in order "Chia sẻ hồ sơ" (S03.01 only), "Báo cáo…", red "Chặn {name}" with `AppIcons.block`), `#S20.01` (title per target, anonymity line, radio list of seven reasons in this order, optional text field, "Chặn {name}" checkbox with its body, one `AppButton.primary` "Gửi báo cáo"), `#S20.01-message` (quote card with sender name and text).

- [ ] **Step 1:** Contract check (every screen file above; S07 plan's Decision 12 menu if #131 landed).
- [ ] **Step 2: Failing tests:** `report sheet titles: "Báo cáo Minh Trí", "Báo cáo bài viết", "Báo cáo tin nhắn", "Báo cáo sự kiện"`; `the seven reasons appear in order; submit disabled until one is picked`; `"Lý do khác" needs 10 characters`; `the block checkbox is hidden for a platform event and for my own content`; `submit sends block when checked and shows "Đã gửi báo cáo và chặn Minh Trí."`; `duplicate shows "Bạn đã báo cáo nội dung này rồi."`; `limit shows the daily-limit text`; `the message variant quotes the sender and text`. `safety_menu_test`: `profile menu shows Chia sẻ hồ sơ, Báo cáo, Chặn Minh Trí; Chia sẻ copies /u/{uid} and says "Đã sao chép liên kết hồ sơ"`; `when I blocked them the row reads "Bỏ chặn Minh Trí"`; `Chặn opens the confirm sheet with the red "Chặn" and the exact body; confirming calls block and says "Đã chặn Minh Trí"`. Screen tests: `S03.01 visitor sees profile-more, the owner does not`; `S02.02 shows photo-more for others' posts only`; `S07.01 shows the menu on an inquiry chat too, with report and block`; `long-press on the other person's message in S07.01 offers "Báo cáo tin nhắn"; on my own message it does not`; `S11.06 non-moderators get "Báo cáo tin nhắn" and "Chặn {name}" on long-press; moderators also keep pin/delete`; `S11.05 timeline row "Báo cáo bài viết" is enabled and opens S20.01 for others' posts`; `S11.02 cover "…" opens "Báo cáo sự kiện"`; `S24.01 visitor "…" opens "Báo cáo {name}"`; `a removed 1-1 message renders "Tin nhắn đã bị gỡ"`.
- [ ] **Step 3:** Run the safety folder and each touched feature folder (one per command); new tests fail.
- [ ] **Step 4: Implement.** Sheet inside `showAppSheet`, `ScreenCode(ScreenCodes.report, …)`, reasons with `ReasonPicker(style: ReasonPickerStyle.radio)`; the profile/photo/cover "…" buttons use the same overlay-circle decoration as their back buttons; long-press menus are `showAppSheet` lists like `_messageMenu`. Strings + `flutter gen-l10n`.
- [ ] **Step 5:** `flutter analyze` clean; tests green per folder.
- [ ] **Step 6: Commit** `feat(safety): S20.01 report sheet and report/block entries on profiles, posts, chats and events [#144]`.

### Task 6: Blocking effects in the app, S20.02 and the settings row

**Files:**
- Create: `app_flutter/lib/features/safety/blocked_users_screen.dart`, `blocked_profile_view.dart`; tests `test/features/safety/blocked_users_screen_test.dart`, `blocked_effects_test.dart`
- Modify: `lib/features/home/home_controller.dart` (drop posts whose `photographerId`/`authorId` is hidden; Home shelves drop hidden photographers), `lib/features/find/find_controller.dart` (`_visible` also drops hidden ids; keeps the look-ahead), `lib/features/photographer_profile/photographer_profile_screen.dart` (`BlockedProfileView` when `hides(uid)`), `lib/features/photo/photo_detail_screen.dart` (hidden author → `EmptyState(postHiddenTitle, postHiddenBody)`; "Thêm của …" filtered), `lib/features/chat/chat_screen.dart` (`blockedAt` → `ChatComposer(enabled: false, disabledReason: …)` + "Bỏ chặn" text button when blocked by me; send error `blocked` → `chatErrBlocked`), `lib/features/events/timeline_tab.dart` (hide tiles of hidden authors), `lib/features/event_chat/event_chat_screen.dart` (skip messages of hidden senders), `lib/features/booking/booking_detail_screen.dart` (blocked pair: no message/contact actions, note `bookingBlockedNote`, link "Liên hệ hỗ trợ" → `/help/chat` only if that route exists), `lib/features/events/register_sheet.dart` (`blocked` → `eventErrBlocked`), `lib/features/settings/settings_screen.dart` (add row "Người đã chặn" `Key('settings-blocked')`, `AppIcons.block` → `/settings/blocked` to group Tài khoản per S09's order (#148 Decision 12): after "Xem hồ sơ công khai", before the staff row "Quản lý sự kiện"; shown to everyone), `lib/app/router.dart` (`/settings/blocked`), S19 list controllers if #143 landed (`lib/features/saved/*`: drop hidden ids), `lib/l10n/app_vi.arb`; tests in the touched folders. Not touched: `booking_sheet_page.dart`, `booking_flow_controller.dart`, `payment_pending_screen.dart`, `qr_checkout_view.dart` (`BookingErrorCode.blocked` → `bookingErrBlocked`: Done in #198 (`2026-10-08-n1-order-gate.md`)).

**Interfaces:** Consumes `hiddenUsersProvider`, `blockIndexProvider`, `SafetyRepository.blocked/unblock`, `confirmUnblock`.

**Backend wiring:** live index listener (Task 4), `get` of `blocks` for S20.02 (index of Task 3), `unblockUser` callable; server refusals (`blocked`) from `sendMessage`, `registerEvent` mapped to copy (`createBooking`/`createPayment` copy is #198's).

**Mock parity:** `#S20.02` (title, note, rows avatar + name + "Chặn {d/M}" + outline "Bỏ chặn", empty state), `#S03.01-blocked` (icon, title, body, outline "Bỏ chặn"; blocked-by-them variant without button), `#S07.01-blocked` (read-only history, closed-composer note with "Bỏ chặn" for the blocker only).

- [ ] **Step 1:** Contract check (controllers and screens above).
- [ ] **Step 2: Failing tests** (`blocked_effects_test.dart` and the touched folders): `a post by someone I blocked is not in the feed`; `a post by someone who blocked me is not in the feed`; `unblocking shows their posts again without restart` (index stream emits); `Find leaves out hidden photographers and still fills the page`; `S03.01 of someone I blocked shows "Bạn đã chặn {name}" and "Bỏ chặn" opens the unblock confirm`; `S03.01 of someone who blocked me shows "Không xem được hồ sơ này" with no button`; `S02.02 of a hidden author shows "Không xem được bài này"`; `S07.01 with blockedAt and blocked by me shows "Bạn đã chặn {name}. Bỏ chặn để nhắn tin." and no composer input`; `blocked by them shows "Không gửi được tin nhắn trong cuộc trò chuyện này." without Bỏ chặn`; `a send refused with blocked shows "Không gửi được: hai bên đã chặn nhau."`; `S11.05 hides tiles of hidden authors`; `S11.06 skips messages of hidden senders`; `S05.02 of a blocked pair has no Nhắn tin and no Liên hệ and shows the support note`; (`booking submit refused with blocked …`: Done in #198); `register refused with blocked shows "Bạn không đăng ký được sự kiện này."`. `blocked_users_screen_test`: `lists blocked people newest first with "Chặn 12/10"`; `"Bỏ chặn" asks "Bỏ chặn Quang Huy?" (not red) and removes the row on success`; `empty state text`; `fits 320dp at 1.3x text`. Settings: `"Người đã chặn" opens /settings/blocked`.
- [ ] **Step 3:** Run the touched folders; new tests fail.
- [ ] **Step 4: Implement.** Filters read `ref.watch(hiddenUsersProvider)`; keep controller page logic unchanged except the filter predicate. Strings + `flutter gen-l10n`.
- [ ] **Step 5:** `flutter analyze` clean; folders green; `dart run tool/affected_test.dart origin/develop --run` green.
- [ ] **Step 6: Commit** `feat(safety): hide blocked users, closed chat and booking notes, S20.02 blocked users [#144]`.

### Task 7: Docs, data model, ledger and status

**Files:**
- Modify: `docs/superpowers/specs/2026-10-01-remaining-screens.md` (§2 S20 cells → "✅ đã làm (#144)"), `docs/superpowers/specs/data-model/domain-model.md` (`Block`, `Report` rows, `ReportTargetType`, `ReportReason`, `ReportStatus` enums, `Chat.blockedAt`; the `blocked` row of `ErrorCode` is Done in #198), `relational-schema.md` (`blocks`, `reports` DDL; `chats.blocked_at`; mapping rows `users/{uid}/private/blocks` → derived from `blocks`), `data-model/README.md` (use cases `block_user`, `unblock_user`, `submit_report`, `decide_report`), `docs/superpowers/specs/screens/report-block.md` (status), `docs/superpowers/handover/ledger-events-10c.md` (strike the "Report sheet … until S20.01" deferred line with a pointer to #144), `docs/superpowers/handover/ledger-c-portfolio-albums-9b-2-L1.md` (same for S24.01)
- Create: `docs/superpowers/handover/ledger-s20-report-block.md`

- [ ] **Step 1:** Edit the docs; check every S20 string against `app_vi.arb` and the mock.
- [ ] **Step 2:** Ledger: rulings, rules/integration tests written not run, deploy order (rules + indexes, then Functions with the gates, then the app; an old app hitting `blocked` shows its generic error), gates of #136/#139/#140/#151 (they call #198's `orderBlocker`; from this plan on they see real blocks), the self-hosted contact-link route without a block check, merges with #131/#143/#148.
- [ ] **Step 3: Commit** `docs(spec): S20 blocks and reports in the data model, ledger [#144]`.

## Deferred

- Staff moderation queue S23.05 — phase 1.5 dashboard (#83); phase 1 is the `reports` CLI.
- Notifying the reporter of the outcome; automatic image moderation (Cloud Vision, open question 21); keyword filtering in inquiries (open question 7).
- Block checks in quotes (#139), Chụp ngay invites (#140), studio assignment (#136), collaborators (#151): written into their plans (they call #198's `orderBlocker`/`BlockGate`); nothing left here.
- Server-side hiding of feed content (the feed is ranked on the device today; a remote recommender must drop hidden pairs — note in `services/recommender/api/openapi.yaml` when it is wired).
- Self-hosted parity (`services/api` contact-link use case without the block check; Go backend phase 2 #90).
- Analytics events (no analytics layer).
