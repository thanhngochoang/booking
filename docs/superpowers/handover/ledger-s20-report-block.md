# Handover ledger — S20 report & block (#144)

Unit: `S20` (issue #144, GitHub Project 6), branch `plan/144-s20-report-block`.
Plan: `docs/superpowers/plans/2026-10-07-s20-report-block.md`. Tasks 1–7.

## What shipped

| Task | Commits | Scope |
|---|---|---|
| 1 Mock & Screen Spec | `b5bcaeb` | UI frames (`S20.01`, `S20.01-message`, `S20.02`, `S03.01-blocked`, `S07.01-blocked`, `S20.01-menu`), `docs/design/ui-mock.html`, `screens/report-block.md` |
| 2 Domain | `4e2e21b` | `block.ts`, `block_ports.ts`, `block_use_cases.ts`, `report.ts`, `report_ports.ts`, `report_use_cases.ts`, memory stores, gates on chat / contact / event |
| 3 Functions, rules, CLI | `e4719e7` | Callables (`blockUser`, `unblockUser`, `submitReport`), Firestore adapters, `Chat.blockedAt` roundtrip, rules & indexes, seed, `tools/reports.ts` CLI |
| 4 App Data | `07444fa` | `lib/data/safety/` (`SafetyRepository`, `FirestoreSafetyRepository`, providers, block index), `ChatErrorCode.blocked`, fake repos |
| 5 S20.01 Report sheet & entries | `1bbcd5e` | `report_sheet.dart`, `report_controller.dart`, `safety_menu.dart`, `block_confirm.dart`, "…" entry points across profile, photo, chat, event, album |
| 6 Blocking effects & S20.02 | `cc76d73` | `blocked_users_screen.dart`, `blocked_profile_view.dart`, filtering in Home & Find, read-only closed chat & booking notes, settings row |
| 7 Docs & Ledger | current | Data model updates (`domain-model.md`, `relational-schema.md`, `README.md`), spec status, ledger |

## Rulings & Key Architectural Decisions

1. **Two-way block hiding**:
   - Blocking someone prevents both parties from viewing each other's content, profile, and messaging each other.
   - Maintained via server-written `users/{uid}/private/blocks` containing `blockedIds` and `blockedByIds`.
   - Realtime `blockIndexProvider` emits updates; clients filter feed posts and photographer listings dynamically without needing an app restart.
2. **Server-side gates**:
   - `openInquiry`: refuses creating new chats between blocked pairs (`blocked`).
   - `sendMessage`: checks `chat.blockedAt != null` before read-only / other guards, throwing `blocked`.
   - `getContactLink`: checks `BlockGate.isBlockedEitherWay(a, b)` before revealing phone/social contact links (`blocked`).
   - `registerEvent`: checks whether the host photographer is blocked either way (`blocked`).
   - `createBookingDraft` & `createPayment`: enforced via order gate (`orderBlocker` / #198).
3. **Existing Bookings Protected**:
   - Active bookings between blocked users remain active so nobody loses money or abandons scheduled work.
   - Outside contact links and 1-1 chat are closed.
   - S05.02 displays `bookingBlockedNote` instructing parties to contact support for communication.
4. **Idempotent Reporting & Quota**:
   - `reports/{id}` uses deterministic document ID `reportDocId(reporterId, targetType, targetId, chatId)`.
   - Submitting the same report twice returns `{duplicate: true}` without creating redundant documents or resetting status.
   - Quota of 20 reports per Vietnam calendar day (`users/{uid}/private/report_quota`).
5. **Staff Moderation**:
   - Phase 1 moderation uses CLI tool `npm run reports -- list|show|dismiss|takedown`.
   - Dashboard web moderation queue S23.05 is slated for Phase 1.5 (#83).
   - Takedown actions:
     - User: disables Firebase Auth user + revokes tokens.
     - Post: hides timeline post and deletes `posts/{id}`.
     - Message: sets `deletedAt`, clearing body and media with text "Tin nhắn đã bị gỡ".
     - Event: prompts staff to cancel via S12.03.

## Deployment Order

1. **Firestore Rules & Indexes**:
   - Deploy `app_flutter/firebase/firestore.rules` (`blocks`, `reports`, `private/blocks`, `private/report_quota`).
   - Deploy composite indexes in `firestore.indexes.json` (`blocks` blockerId ASC createdAt DESC, `reports` status ASC createdAt ASC).
2. **Cloud Functions**:
   - Deploy callables `blockUser`, `unblockUser`, `submitReport`.
   - Deploy updated triggers and gates (`openInquiry`, `sendMessage`, `getContactLink`, `registerEvent`).
3. **Client App**:
   - Release Flutter app containing S20.01, S20.02, safety menu, and filtering logic.

## Emulator Suites Written (Run in CI)

- `app_flutter/firebase/rules-test/rules.test.mjs`: security rules test for `blocks` (owner read only) and `reports` (client read/write disallowed).
- `app_flutter/firebase/functions/test/integration/block.test.ts`: end-to-end callable flow testing block creation, gate checks, and unblock restoration.

## Deferred Items

- S23.05 Staff Moderation Web Queue (#83; phase 1 uses `npm run reports` CLI).
- Push notification to reporter upon report resolution.
- Automated image scanning with Cloud Vision API (Open question 21).
- Keyword filtering in chat inquiries (Open question 7).
- Recommender service remote filtering (`services/recommender` note).
- Self-hosted `services/api` parity for block checks on contact links.
