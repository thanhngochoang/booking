# Handover ledger — 8d/5-L2 (Chat Domain, Functions, Rules, Indexes & Data Layer)

Unit: `8d/5-L2` (Lane 2 Step 5)  
Branch: `plan/8d-5-L2-chat-core-data`  
Target: `develop`  

## Scope Completed

### 1. Task 1: Chat Domain Model & Rules (`packages/domain/src/`)
- `chat.ts`:
  - Defined types: `ChatKind`, `MessageType`, `ChatMessage`, `ChatThread`, `RescheduleProposal`, `SystemPayload`, `ChatErrorCode`, `ChatError`.
  - Implemented domain validation functions: `validateThreadTransition`, `validateMessageSend`, `normalizeProposal`.
- `chat_ports.ts`:
  - Defined `ChatStore` port with transactional operations (`runTransaction`, `getChat`, `setChat`, `getMessage`, `addMessage`, `updateMessageSystem`, `incrementUnread`).
  - Strict read-before-write semantics enforced.
- `memory_chat_store.ts`:
  - In-memory implementation of `ChatStore` for fast, zero-dependency testing.
- Exported all types and ports from `packages/domain/src/index.ts`.
- Tests in `packages/domain/test/chat.test.ts`.

### 2. Task 2: Domain `openInquiry` & `sendMessage` (`packages/domain/src/`)
- `open_inquiry.ts`:
  - Opens idempotent thread `${customerId}_${photographerId}`.
  - Enforces photographer inquiry opt-out flag check (returns existing chat if inquiries off, rejects new inquiry).
- `send_message.ts`:
  - Enforces 3-message inquiry cap for customers until photographer replies (`limit_exceeded`).
  - Lifts cap permanently once photographer replies.
  - Idempotent deduplication by `clientId`.
  - Atomically increments recipient's unread counter and updates thread preview/lastMessageAt.
- Tests in `packages/domain/test/open_inquiry.test.ts`, `packages/domain/test/send_message.test.ts`, and `support/chat_world.ts`.

### 3. Task 3: Domain Reschedule Proposal & Answer (`packages/domain/src/`)
- `reschedule.ts`:
  - `proposeReschedule`: Allows either party to propose reschedule on an accepted booking with available free change (`rescheduleUsed == false`). Fails with `limit_exceeded` if already used, or `conflict` if another proposal is pending.
  - `answerReschedule`: Validates recipient is not the proposer. On accept: moves booking calendar day, updates availability, sets `rescheduleUsed: true`. On decline: preserves free change. On conflict/taken day: returns `day_taken`.
- Tests in `packages/domain/test/reschedule.test.ts`.

### 4. Task 4: Booking <-> Chat Sync Trigger Logic (`packages/domain/src/`)
- `booking_chat_sync.ts`:
  - Automatically provisions booking chat thread when a booking is created.
  - Propagates booking lifecycle status events into system messages on the chat thread.
  - If a booking is cancelled, auto-expires any pending reschedule proposals.
- Tests in `packages/domain/test/booking_chat_sync.test.ts`.

### 5. Task 5: Functions, Rules & Indexes
- **Firestore Security Rules (`app_flutter/firebase/firestore.rules`)**:
  - Authored via `firestore-rules-author` subagent.
  - Added rules for `chats/{chatId}` and subcollections (`messages`, `members`).
  - Read: members only.
  - Write: blocked for clients (all mutations go via Functions), except `members/{uid}` which allows owner to zero `unreadCount` with `lastReadAt == request.time`.
- **Firestore Security Rules Tests (`app_flutter/firebase/rules-test/rules.test.mjs`)**:
  - Tests for member-only read, client write prohibition, and zeroing unread counter.
- **Storage Rules (`app_flutter/firebase/storage.rules`)**:
  - Added rules for `chats/{chatId}/{uid}/{file}` allowing member image uploads under 10MB with image MIME types.
- **Composite Indexes (`app_flutter/firebase/firestore.indexes.json`)**:
  - Added index on `chats` collection: `members` (ARRAY_CONTAINS) + `lastMessageAt` (DESCENDING).
- **Cloud Functions (`app_flutter/firebase/functions/src/`)**:
  - `infra/chat_firestore.ts`: Firestore mapping for chats, messages, and transactional persistence.
  - `infra/live_chat.ts`: Live chat store adaptor for callable functions.
  - `callables/chat.ts`: Callables `openInquiry`, `sendMessage`, `proposeReschedule`, `answerReschedule` running in `asia-southeast1`.
  - `triggers/booking_write.ts`: `onBookingWrite` trigger handling booking <-> chat synchronization.
  - Exported functions in `functions/src/index.ts`.
- **Functions Tests**:
  - `test/unit/chat_firestore.test.ts`, `test/unit/chat_callables.test.ts`, `test/integration/chat.test.ts`.

### 6. Task 6: App Data Layer (`app_flutter/lib/data/chat/`)
- `chat.dart`:
  - Models: `ChatKind`, `MessageType`, `MessageSendState`, `RescheduleProposal`, `SystemPayload`, `ChatThread`, `ChatMessage`, `ChatListItem`.
  - Firestore snapshot deserialization with Timestamp and GeoPoint handling.
- `chat_repository.dart`:
  - `ChatRepository` interface with `watchThread`, `watchMessages`, `olderMessages`, `watchMyChats`, `watchTotalUnread`, `openInquiry`, `sendText`, `sendImage`, `sendLocation`, `markRead`, `proposeReschedule`, `answerReschedule`.
  - `ChatErrorCode` enum and `ChatException`.
- `firestore_chat_repository.dart`:
  - Production Firestore and Cloud Functions implementation.
  - Robust callable error code mapping (`mapFunctionsError`).
- `chat_providers.dart`:
  - Riverpod providers: `chatRepositoryProvider`, `chatThreadProvider`, `chatMessagesProvider`, `myChatsProvider`, `totalUnreadProvider`.
- `app_flutter/lib/data/location/`:
  - Updated `LocationRepository` and `GeolocatorLocationRepository` with `currentPosition({Duration timeout})`.
- **Test Support & Tests**:
  - `app_flutter/test/support/fake_chat_repository.dart`: Full fake repository with seeding, pagination, idempotency, failure injection (`failNext`), and offline simulation.
  - `test/data/chat/chat_mapping_test.dart`: 22 tests verifying Firestore round-trips and comprehensive error code mapping.
  - `test/data/chat/fake_chat_repository_test.dart`: 10 tests verifying 3-message limit, retry by clientId, unread counts, reschedule lifecycle, and stream updates.

## Verification
- `(cd packages/domain && npm test)`: 184/184 passed.
- `(cd packages/domain && npm run lint && npm run typecheck)`: 100% clean.
- `(cd app_flutter/firebase/functions && npm test)`: 63/63 passed.
- `(cd app_flutter/firebase/functions && npm run lint && npm run typecheck)`: 100% clean.
- `(cd app_flutter && flutter analyze)`: 0 issues found.
- `(cd app_flutter && flutter test)`: 1544/1544 passed.

## Gate Status
- Reaches Gate **G5** (Lane 2 merges 4d Tasks 1–6).
- Unblocks Lane 1 Step 6 (4d Tasks 7–9: S07.01, entry points, S07.02).
