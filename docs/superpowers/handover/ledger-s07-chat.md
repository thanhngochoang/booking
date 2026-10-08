# Handover ledger — plan S07 chat (issue #131)

Plan: `docs/superpowers/plans/2026-10-07-s07-chat.md`, Tasks 1–7. Branch `plan/131-s07-hoi-thoai`. Merge base 6e95637 (#147 already merged: chat uploads were already `.jpg` with `ImagePurpose.chat`). Commits: de9e006 and 3904dae (domain), dff9e6d (functions + seed), 4ce4451 and 775253e (app data), 5a53e41 (S07.01), 4aeccf7 and 013a793 (S07.02), then the docs commit of Task 7. Execution notes of each task: `.superpowers/sdd/2026-10-07-s07-chat/`.

## Built

- Task 1 (domain, `packages/domain`): `Chat.bookingStatus`; `isInquiryClosed` uses `lastMessageAt ?? createdAt` + 14 days (never for booking chats); `validateMessageInput(raw, senderId?, chatId?)` rejects an image path of another chat and requires exactly four segments; `sendMessage` refuses a customer's message into a closed inquiry with `not_eligible` when the photographer has inquiries off (the flag is read only on that path, after the `clientId` idempotency check); `openInquiry` turns a read-only booking chat back into an inquiry (Decision 3, Ruling 3); `syncBookingChat` mirrors `bookingStatus` in every branch (attach, accepted, cancelled, completed, `upcoming`, `reviewed`) and not for another booking of the same pair.
- Task 2 (Functions): `toFirestoreChat` / `fromFirestoreChat` map `bookingStatus` (non-string reads as null; the mapping itself landed with Task 1 to keep typecheck green); callable tests for the closed inquiry and the revive; seed `directChatDocuments`: booking chat Lan–An (status read from the seeded booking, Lan unread 2), closed inquiry Lan–Cúc (20 days old), open inquiry Minh–Dũng (Dũng unread 1) plus README table "Chats (S07)".
- Task 3 (app data): `ChatThread.bookingStatus`, `inquiryCloseDays`, `ChatThreadRules.isClosedInquiryAt` / `bookingStatusValue`, `bookingStatusFromCode`; `watchMyChats` = one query listener + one listener per member doc (no `get`, first list waits for the member docs, hidden chats get no listener); `watchTotalUnread` and `sendImage` removed, `uploadChatImage` + `sendImagePath` added; `chatImageUrlProvider` (keep-alive after success, errors retried); `totalUnreadProvider` sums `myChatsProvider`; the repository now takes `mediaUploader` from `mediaUploaderProvider`. Fix round: `uploadChatPhoto` (`lib/data/chat/chat_photo_upload.dart`) shared by the 1-1 and event chat repositories.
- Task 4 (S07.01): controller keeps `_images` and `_uploaded` per `clientId`; retry posts the same path without uploading again; `localFileFor`; `ChatState.errorCode/errorSeq` drive a snackbar; every `state =` after an await is `ref.mounted`-guarded; `bubbleContentOf(imageUrl:, localPath:)`; closed inquiry line from `isClosedInquiryAt`; `…` menu ("Xem buổi chụp" for booking chats, "Xem hồ sơ" for the customer in an inquiry); hard-coded strings replaced by l10n (`chatNotFound`, `chatMe`, `chatViewProfile`, `chatInquiriesOff`).
- Task 5 (S07.02): badge = `StatusBadge(bookingStatusValue)` (none without a status); closed inquiry preview `chatClosed` (wins over "Bạn: "); empty preview of a booking chat shows the status sentence (`bookingStatusSentence`; `upcoming` falls back to the accepted sentence, `reviewed` to the completed one); own last message `chatsYouPrefix` ("Bạn: {text}"); role-name fallbacks from l10n.
- Task 6: done by #147 + Tasks 3–4, no commit of its own (see below).
- Task 7 (docs, this commit): mock S07.02 first row badge "Đã đặt" → "Đã nhận" and caption (badge = booking status label); the same sample in `scripts/tools/build_ui_components.py` and the generated `docs/design/ui-components.html`; `screens/booking.md` S07.01 and S07.02; main spec §2 status cells, §3b.1 (closed inquiries, reopen, revive, `bookingStatus`) and the S07.01 row of the per-screen table (photo 1280 px q75); `domain-model.md` (`Chat.bookingStatus` read model, revive, derived "closed"); `relational-schema.md` mapping row (no column, derived from `bookings.status`).

## Decisions of the plan (2026-10-07)

1. An `inquiry` is closed when `now ≥ (lastMessageAt ?? createdAt) + 14 days`. Turning off `acceptInquiries` does not close inquiries. Closed is derived, never stored; any message reopens it.
2. A customer's message into a closed inquiry is refused with `not_eligible` when the photographer has `acceptInquiries == false`; an open inquiry continues; the photographer can always reply and reopen; closing does not reset the 3-message cap.
3. A read-only booking chat becomes an inquiry again when the customer taps "Nhắn tin hỏi trước" (keeps history and `photographerRepliedAt`; refused with `not_eligible` when inquiries are off).
4. The booking status is mirrored on the chat (`chats/{id}.bookingStatus`, written by `syncBookingChat` on every status change including `upcoming` and `reviewed`).
5. The S07.02 badge is the booking status label (`BookingStatusX.label`), not the hard-coded "Đã đặt"; the mock contradicted itself, so the mock's S07.02 badge became "Đã nhận".
6. Retry never re-uploads a stored image (Storage forbids overwrite): upload and send are split, the controller remembers the uploaded path per `clientId` (one screen session).
7. Image path extension `.jpg`; the server also checks `parts[1] === chatId`.
8. Download URLs are resolved once per app run (`chatImageUrlProvider`); the sender's just-sent photo keeps the local file.
9. Unread counts: one query listener + one listener per member doc (≤ 50); `totalUnreadProvider` sums the list.
10. Chats without any message are hidden from S07.02.
11. An empty preview of a booking chat shows the `chatSys*` sentence of its status; own last message gets "Bạn: ".
12. `…` in S07.01 shows only when it has an item (booking chat: "Xem buổi chụp"; customer in an inquiry: "Xem hồ sơ"); the report item (S20) will make it always present.
13. `/chats` stays outside the tab shell.
14. Chat photos 1280 px q75 without EXIF supersede the screen spec's "≤ 2048px (WebP)".

Owner answers (INDEX): Q1 yes (Decision 2), Q2 yes (Decision 3), Q3 plan default (keep `/chats` without the tab bar).

## Rulings made during execution

1. Task 3 builds `uploadChatImage` on #147's code (keeps `purpose: ImagePurpose.chat` and the `.jpg` path) and wires the chat repository's uploader through `mediaUploaderProvider` instead of creating its own compressor. Cost if wrong: one more provider override in tests.
2. Task 6 keeps only what #147 did not already do. Cost if wrong: none.
3. A revived chat gets `photographerRepliedAt = existing ?? now` (they already talked during the booking). Cost if wrong: a revived chat skips the 3-message cap before the photographer replies.
4. Bubble size from `UploadedMedia` width/height is not built: the mock's own photo bubble is square, so nothing reads it. Cost if wrong: a later bubble with the true aspect ratio needs width/height stored on the message.

Accepted deviations: Task 3 — the first list emission waits for the member docs (no flash of unread 0); member listeners only for visible chats. Task 4 — a sent photo of mine passes `localPath` and no `imageUrl` (core `ImageContent` shows the local file only when the URL is empty).

## Task 6 status

Done by #147 + Tasks 3–4, no separate commit: the chat upload uses `ImagePurpose.chat` (1280 px, q75, EXIF stripped) in `app_flutter/lib/data/chat/chat_photo_upload.dart`, pinned by `test/data/chat/chat_photo_upload_test.dart`; retry reuses the uploaded path and an upload failure uploads again (controller tests of Task 4). The `chats/` Storage rule (`jpegUpTo`) belongs to #147.

## Verification and skipped suites

- Domain `npm test` 903 pass, typecheck and lint clean (Tasks 1–2). Functions `npm test` 308 pass, lint, typecheck and build clean (Task 2).
- Flutter: `test/features/chat` 63 pass; `test/data/chat`, `test/data/booking`, `test/features/home` pass; one full `flutter test --no-pub` after Task 3 (+3379, all passed); `flutter analyze --no-pub` clean. `dart run tool/affected_test.dart` could not run in the sandbox (its inner pub get is blocked), so affected folders were run by hand.
- Skipped: the emulator suites (`npm run test:integration` of Functions and the rules tests in `firebase/rules-test`). Nothing in them is touched: no rule, index, callable, trigger or schedule changed; CI runs them on push.
- Task 7 ran `test/core/screen_codes_test.dart` (it reads only the code column of the main spec table, the status cells are free text).

## Mock deviations kept

- S07.02 is drawn with the bottom tab bar in the mock; the app opens `/chats` outside the tab shell (Decision 13), because it is opened from S02.01 and S05.01 (two tabs) and from push links, and moving it under one branch would switch tabs. Noted in `screens/booking.md`.
- S07.01 context card thumbnail (mock `.ctx .th`) is not drawn: see deferred.

## Deploy order and release note

- Deploy the Cloud Functions before the app release, so `bookingStatus` is written when the new list asks for it. A chat document written before this release has no `bookingStatus`, so its row shows no badge until its booking changes status (dev data only today). Optional, not planned: touch old chats with a one-off Admin script that copies `bookings.status` into `chats.bookingStatus`.
- No rules, index or schedule to deploy. New chat photos are named `.jpg`; stored messages keep their old paths.
- Release note (Vietnamese): "Tin nhắn: ảnh hiện cho cả hai bên và gửi lại được khi lỗi mạng; danh sách hội thoại hiện đúng trạng thái booking, tiền tố "Bạn:" và cuộc trò chuyện hỏi trước đã đóng; mở lại chat với nhiếp ảnh gia sau khi booking kết thúc."
- Cost (plan estimate, nam5 upper bound): net about −0.57 USD/month at 1,000 MAU and −5.7 at 10,000 MAU from the unread listeners; photo egress is the only line that grows (+0.11 / +1.08 with #147's compression).

## Deferred (not in this unit)

From the plan:
- Report a message / a user from the `…` menu (S20, #144); this makes `…` always present as in the mock.
- `/chats` inside the tab shell (Decision 13).
- Context card thumbnail from the package cover: the booking snapshot carries no cover; needs a `coverUrl` in `serviceSnapshot` (no owner yet: #129 merged without it, see the S04 reconciliation note).
- Full-screen photo viewer and a 480 px bubble thumbnail (with #147's variants).
- Persisting failed messages across restarts (in memory only, as before).
- `stats.responseMinutes` (reply time) computed from chats for the "Trả lời nhanh" reason and badge (S02 / badges follow-up).
- Keyword filter in inquiries (phone numbers, "chuyển khoản"): open question in the main spec.

Minors found in review and parked:
- Task 1: a revived chat can be born already "đã đóng" (old `lastMessageAt`); out-of-order booking trigger events can regress `bookingStatus` until the next event.
- Task 3: Riverpod's default retry in production versus `retry: null` in tests for `chatImageUrlProvider`; unrelated formatter rewraps (`answerReschedule`); `ChatThread.copyWith` cannot clear `bookingStatus`.
- Task 4: `retryMessage` on an image does not set `isUploadingImage`; a failed text send shows the generic "Không thực hiện được" snackbar next to the "Gửi lại" bubble (it fires from `errorSeq` for any failure; consider suppressing it for text sends); long lines not `dart format`ted; `ref.watch(chatImageUrlProvider)` sits inside the list `itemBuilder`; the controller test named "closed inquiry" does not seed one.
- Task 5: the old "320 dp, 1.3×" list test overlaps the new fits-320dp test.
- A just-sent photo stays on its local file for the screen session; if the OS cleaned the temp file the bubble shows a plain colour block until the screen is reopened.
