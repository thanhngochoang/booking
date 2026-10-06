# 10a: Notifications (S17.01–S17.03) and badges (S03.02) Implementation Plan

> **Battery/performance (2026-10-02, user):** no battery, idle or performance steps; they run once in `docs/superpowers/plans/2026-10-02-final-battery-performance.md`. Keep the functional tests (one listener only while S17.01 is open, no polling, debounced read marks).

> **Rules emulator tests (2026-10-02, user):** this plan changes `firestore.rules`, indexes and adds Functions. Write the rules tests and the Functions integration tests; do not run them, CI runs them. Record the skips in the ledger.

> **No lanes:** one session runs Tasks 1–7 in order. Tasks 1–3 are server, 4 is app data and core, 5–7 are screens.

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

> **Detail level (user, 2026-10-02):** exact interfaces, tests listed by name with expected behaviour, sample code only for the parts easy to get wrong.

**Goal:** Users get an in-app inbox (S17.01) fed by the server for booking, review, award, badge and chat events, with live unread count on the Hồ sơ tab and the S09.01 "Thông báo" row, FCM push that respects per-category settings and quiet hours (S17.02), a permission primer shown only after a meaningful action (S17.03), and a badges screen (S03.02) backed by server-awarded badges, owner-only progress and a "Mới" dot.

**Architecture:** One domain use case `notify` (packages/domain) decides from the type table and the user's prefs whether to write an inbox row and/or push, renders the Vietnamese title/body, de-duplicates by a deterministic id and groups by `groupKey`; Functions are thin adapters (Firestore store, FCM sender, triggers on bookings, reviews, chat messages, awards, posts, users; one callable `markAllNotificationsRead`; reminder sweep in the existing `bookingClock`). `users/{uid}.unreadCount` is recomputed (count aggregation) by a trigger on every inbox-row write, so it is idempotent under retries. Badges: a catalogue constant in the domain (synced to `badges/{id}`), a pure evaluator over metrics read through a port, writes to `users/{uid}/badges` (public) and `users/{uid}/private/badgeProgress` (owner), and `badge_new` notifications. The app reads through `NotificationRepository`, `NotificationPrefsRepository`, `BadgeRepository` and two platform ports (`PushMessaging` over `firebase_messaging`, `NotificationPermissionPort` over `permission_handler`); the client writes only `readAt` and its own prefs.

**Tech Stack:** TypeScript (domain, Functions v2: callables, `onDocumentCreated/Written`, `onSchedule`, `firebase-admin/messaging`), Firestore rules and indexes; Flutter, Riverpod 3, go_router, new deps `firebase_messaging`, `permission_handler`; Android notification channels in `MainActivity.kt`; existing `AsyncView`, `SegmentedTabs`, `SectionHeader`, `NotificationRow`, `BadgeRow`, `BadgeTile`, `PermissionPrimer`, `PermissionPrimerPolicy`, `TabBadge`, `showAppSheet`, `OfflineBanner`, `EmptyState`, `ErrorState`.

**Spec:** main spec `docs/superpowers/specs/2026-10-01-remaining-screens.md` §3h (all), §3d.2–3d.3, §1 (60-30-10, `AppIcons`); `docs/superpowers/specs/screens/account.md` S17.01, S17.02, S17.03, S03.02, S09.01, S09.02; `screens/portfolio-awards.md` "S09.01 · dòng Thông báo"; `screens/discovery.md` S03.01 (badge row); `components/shared-components.md` → NotificationRow, NotificationBell, PermissionPrimer, BadgeChip, BadgeTile, TabBadge; `data-model/domain-model.md` (`Notification`, `NotificationType`, `Device`, `BadgeDefinition`, `UserBadge`, `BadgeProgress`), `relational-schema.md` §2.1, §2.5, §2.7; mock `docs/design/ui-mock.html` `#S17.01`, `#S17.02`, `#S17.03`, `#S03.02`, `#S09.01`, `#S03.01`.

**Prerequisite:** develop at or after PR #31 (9a/9b/9c lane 1) and plan 9d (`AppIcons`, 60-30-10) merged.

## Contract with existing code

Task 1 Step 1 checks the server part, Task 4 Step 1 the app part; adapt and ledger any difference. Nothing below exists yet unless listed here (checked 2026-10-06 on `plan/9d-icons-603010`): **no** notification store, `notify`, FCM sender, `devices` rules, `unreadCount` writer, badge catalogue or badge evaluator; `NotificationBell` is not used by any screen.

- Domain: `DomainError` + `ERROR_CODES`, `Clock`, `IdGenerator`, `isId`, `parseVnDateTime`, `formatVnDate`, `formatVnTime`, `refundPercent`, `Booking`/`BookingStatus`/`BookingCancel`, `transitionBooking` + `runBookingSweeps` (`booking_sweeps.ts`), `countReview` + `addRating` + `StatsTx` (`review_stats.ts`), `Review`, `sendMessage`/`Message`/`MESSAGE_TYPES`, `AwardDeps.notify { tierChanged(uid, to), awardReviewed(uid, awardId, status) }`, `AWARD_STATUSES`, `src/index.ts` export list.
- Functions: `CALLABLE_OPTIONS`, `TRIGGER_OPTIONS`, `SCHEDULE_OPTIONS`, `toHttpsError`/`CallableInput` (`callables/errors.ts`), `db()` (`infra/admin.ts`), `bookingFromFirestore`, `handleBookingWrite(event, deps: ChatDeps, updateChatId?)` (chat sync only), `handleReviewWrite` + the no-op `awardBadgesAfterReview` (review_write.ts), `handlePostCreated`, `handleBookingClock`, `liveAwardDeps()` with logged no-op `notify` ("Push notifications arrive with plan S17"), `onPhotographerWrite`, `seed/fixtures.ts` (seed users Lan, Minh, An, Bình, Cúc, Dũng, admin; bookings `seed-booking-*`).
- Rules: `signedIn()`, `isOwner()`, `onlyKeys()`, `userClientFields()` (no `unreadCount`), `match /users/{uid}` + `match /private/{docId}` (only `contact` writable), `chats/{chatId}/members/{uid}` (client resets `unreadCount` to 0), catch-all deny. Indexes: `bookings (photographerId, status)`, `reviews (photographerId, createdAt desc)`, `posts (photographerId, createdAt desc)`.
- App data: `authStateProvider`, `currentProfileProvider` (`UserProfile {uid, role, displayName, avatarUrl}`), `AuthRepository.signOut`, `sharedPreferencesProvider` (`features/settings/theme_mode_controller.dart`), `functionsRegion`, the callable pattern of `FirestoreAwardRepository._call` (15 s timeout, `details.code` → error code), `photographers/{uid}.stats.{rating, reviewCount, completedCount, responseMinutes}` read by `firestore_photographer_repository.dart`.
- Core: `NotificationRow`/`NotificationRowData`/`NotificationKind`/`notificationKindIcon` (`notification_row.dart`), `NotificationBell`, `PermissionPrimer({title, benefit, onEnable, onLater, enableLabel?, laterLabel?})`, `PermissionPrimerPolicy`/`PrimerStore`, `BadgeView(code, name, condition, earned)`, `BadgeProgress(current, total)`, `badgeIconOf(code)`, `BadgeChip`, `BadgeRow({badges, max, onSeeAll})`, `BadgeTile({badge, progress, isNew, onTap})`, `TabBadge({count, child})` (semantics "{n} mục mới"), `SegmentedTabs`, `SectionHeader`, `AsyncView`, `EmptyState`, `ErrorState`, `OfflineBanner`, `showAppSheet`, `showConfirmSheet`, `AppIcons` (`notifications`, `notificationsActive`, `notificationsOff`, `doneAll`, `calendar`, `camera`, `work`, `instant`, `payment`, `ticket`, `award`, `check`, `checkCircle`, `star`, `chat`, `info`, `favorite`, `share`, `profile`, `schedule`, `medal`, `celebration`), `ScreenCodes.notifications/notificationSettings/notificationPermission/badges`, `toVn()`, `formatMoney`.
- Features: `ProfileTab` (`features/shell/placeholder_tabs.dart`, S09.01: avatar, name, role, `_MyAlbumsRow`, `AwardNudgeRow`), `tabBadgesProvider` (`features/shell/tab_badges.dart`), `TabShell`, `SettingsScreen` (`_SectionLabel` groups, `_confirmSignOut`), `PhotographerProfileScreen` + `ProfileHeader` (S03.01; bio then tabs), `BookingDetailScreen(justPaid)` (`/b/:id?paid=1`, `_transition` accept), `WorkScreen._accept`, router (`/u/:uid/albums/:albumId` before `/u/:uid`; `/settings` with child `profile`; `bookingDetailRoutes()` `/b/:id`; `/chat/:chatId`; `/me/awards`; tabs `/home`, `/explore`, `/action`, `/bookings`, `/profile`), `profileSectionFromQuery('reviews')`, the analytics hook pattern of `features/skills/skills_analytics.dart`.

If a member named here does not exist, stop and report instead of guessing.

## Global Constraints

- "Chỉ server ghi thông báo và `unreadCount`. Client chỉ được đặt `readAt` (rule Firestore giới hạn đúng trường này); "Đánh dấu tất cả đã đọc" gọi callable `markAllNotificationsRead`."
- "Mặc định `prefs`: mọi loại bật Push và Trong app, riêng `promo` tắt cả hai; giờ yên lặng 22:00–07:00 bật; nhắc 24 giờ và 2 giờ bật." "Tôn trọng `prefs` ở server: kênh Trong app tắt thì không tạo dòng; kênh Push tắt thì không gửi FCM."
- "Không polling. Chỉ lắng nghe 30 mục mới nhất **khi S17.01 đang mở**; ở nơi khác chỉ lắng nghe trường `unreadCount` của `users/{uid}`." "Đánh dấu đã đọc được gom lô (debounce ~1 giây hoặc khi rời màn) thành một `WriteBatch`; cập nhật lạc quan ở UI." "Push chỉ mang `type`, `target` và tiêu đề/nội dung ngắn."
- "Giờ yên lặng … (múi giờ Asia/Ho_Chi_Minh): push đến im lặng (không âm, không rung), vẫn vào hộp thư. Ngoại lệ, vẫn phát âm: **giao dịch quan trọng** là lời mời Chụp ngay khi NAG đang bật "Live Shutter", thanh toán, và huỷ lịch."
- "Chỉ hỏi **sau một hành động có ý nghĩa**, không bao giờ khi mở app lần đầu." "'Để sau' lưu thời điểm và hỏi lại sau **7 ngày**." "Nếu OS đã từ chối vĩnh viễn thì không hỏi lại mà dùng banner của S17.02." "Token FCM chỉ đăng ký sau khi cấp quyền."
- "Chấm số: đọc từ `users/{uid}.unreadCount`, "9+" từ mười trở lên, ẩn khi 0. Trình đọc màn hình đọc "3 thông báo chưa đọc", không đọc số trần." "Chưa đọc = chấm tím bên trái **và** nhãn ngữ nghĩa "Chưa đọc"." "Nhấn giữ mở menu "Đánh dấu đã đọc / Tắt loại thông báo này" (không có thao tác chỉ vuốt)."
- "Mỗi loại đúng một biểu tượng; tông màu theo ngữ nghĩa (xanh = thành công, vàng = cần hành động, đỏ = bị từ chối, tím = mặc định)." (Tím here = the neutral `primarySubtle` disc of the mock `.nic`; 60-30-10 keeps purple out of everything else.)
- "Lời mời Chụp ngay không là thông báo trong hộp thư."
- S03.02: "người khác chỉ thấy huy hiệu đã đạt, ẩn tiến độ"; "huy hiệu mới đạt có chấm "Mới" đến lần mở kế tiếp"; "client không ghi huy hiệu; tích xanh Verified không xuất hiện ở đây". §3d.2: "Chống thổi phồng: mỗi huy hiệu từ đánh giá có `minSample`; đánh giá chỉ tính từ booking `completed`." "tối đa 3 huy hiệu trên … hàng tên (ưu tiên theo `order`)".
- Copy is verbatim from the mock where mock and spec differ (CLAUDE.md "UI matches the mock"): S17.01 header "{n} chưa đọc" + "Đánh dấu tất cả đã đọc"; S17.02 banner body "Bạn sẽ không nhận push cho tới khi bật lại.", quiet line "22:00–07:00 · chỉ thông báo quan trọng vẫn có âm", reminder chips "24 giờ" / "2 giờ", column header "Loại"; S17.03 benefits "Biết ngay khi lịch được nhận hoặc thay đổi" / "Nhắc trước giờ chụp, không lỡ hẹn" / "Tin nhắn mới khi app đang ở nền" and the note "Chọn "Để sau", chúng tôi sẽ hỏi lại sau 7 ngày."; S03.02 "Huy hiệu", "Từ đánh giá", "Từ hệ thống", "{cur} / {target}". Other strings: the `s63_*`, `s64_*`, `s65_*`, `s37_*` lists in `screens/account.md`, as camelCase app keys with prefixes `notif…`, `notifSettings…`, `primer…`, `badges…` (Vietnamese text verbatim).
- CLAUDE.md: Firebase (`cloud_firestore`, `firebase_messaging`, …) only in `lib/data/**` adapters, `firebase_options.dart`, `main.dart`; `permission_handler` only in its adapter; business rules in `packages/domain` (no Firebase/Node imports); Functions thin; strings in `app_vi.arb`; `AsyncView` for every `AsyncValue`; tokens and `AppIcons` only; one primary action per screen; `package:photobooking/...` imports; features import `core/core.dart`; every screen and sheet wrapped in `ScreenCode`; commits end with `Co-Authored-By: TonyH <thanhngochoangbk@gmail.com>`.

## Decisions (where the spec is silent)

1. **Type table** (domain `NOTIFICATION_TYPES`, single source; the app mirrors only icon/tone). Every type of §3h.2 plus `booking_cancelled` (domain-model already lists it; §3h.5 calls "huỷ lịch" critical but §3h.2 has no row — Task 7 adds the row). Columns: `category` (S17.02 row), `tab` (S17.01 filter bucket), `critical`:

   | type | category | tab | critical | emitted by this plan |
   |---|---|---|---|---|
   | `booking_request` | booking | activity | – | yes (photographer, → `requested`) |
   | `booking_accepted`, `booking_declined` (variants `declined`/`expired`) | booking | activity | – | yes (customer) |
   | `booking_cancelled` | booking | activity | ✓ | yes (the other party; both when `cancel.by == 'system'`) |
   | `refund_done` | booking | activity | ✓ | yes (customer, `depositRefundedAt` null → set, `depositRefunded > 0`) |
   | `shoot_reminder` (variants `h24`/`h2`) | booking | activity | – | yes (both parties, reminder sweep) |
   | `payout_released` | booking | system | ✓ | no (payout plan) |
   | `quote_new`, `quote_withdrawn`, `job_expiring`, `job_expired`, `job_match`, `job_invited`, `quote_accepted`, `quote_not_selected`, `job_selected` | jobs | activity | – | no (D-plans) |
   | `instant_assigned`, `instant_missed` | instant | activity | – | no (instant plans) |
   | `event_soon` | events | events | – | no (events plans) |
   | `review_new`, `badge_new` | badges | system | – | yes |
   | `award_reviewed`, `artist_granted`, `artist_revoked` | badges | system | – | yes (replaces the logged no-op in `liveAwardDeps`) |
   | `chat_message` | chat | system | – | yes (grouped per chat) |
   | `promo` | promo | system | – | no |

   `tab` is stored on each row and the filter queries `where('tab', '==', …)`; the spec's "lọc theo `type` ở truy vấn" would need `type in [...]` per role and breaks for users who switch modes (a `shoot_reminder` is Đặt lịch for a customer and Công việc for a photographer). The customer's "Đặt lịch" and the photographer's "Công việc" tabs are the same `activity` bucket with a role-dependent label. Task 7 updates the spec sentence.
2. **Who renders text.** The server renders `title`/`body` (Vietnamese, `renderNotification(content)`, pure) and stores them; push needs the text when the app is not running, so there is one source. The app shows the stored text; ARB holds only UI chrome. Copy (mock rows verbatim where the mock has one):
   - `booking_request`: "Yêu cầu đặt lịch mới" / "{customer} · {service}, {day} · {start}. Còn 24 giờ để nhận."
   - `booking_accepted`: "{photographer} đã nhận lịch" / "{day} · {start}, {place}. Nhắn tin để chốt chi tiết."
   - `booking_declined` declined: "{photographer} không nhận được lịch" / "Cọc đã hoàn {percent}%. Xem các nhiếp ảnh gia còn rảnh."; expired: "{photographer} chưa trả lời kịp" / "Yêu cầu đã hết hạn. Cọc đã hoàn {percent}%."
   - `booking_cancelled`: by a party "{name} đã huỷ lịch" / "{day} · {start}." + (customer recipient) " Cọc hoàn {percent}%."; by system "Lịch {day} · {start} đã bị huỷ" / "Xem chi tiết trong lịch hẹn."
   - `refund_done`: "Đã hoàn {amount}" / "Khoản cọc buổi chụp #{code} đã về tài khoản của bạn." (`code` = last 4 of the booking id, upper case, like `bookingCode()` in the app; `amount` "450.000₫").
   - `shoot_reminder`: "Nhắc lịch: còn {24|2} giờ" / "{service} với {counterpart}, {day} lúc {start}."
   - `review_new`: "{customer} đã đánh giá {rating} sao" / "“{text, first 80 graphemes…}”"
   - `badge_new`: "Bạn nhận huy hiệu “{name}”" / "{description}"
   - `award_reviewed`: approved "Giải thưởng đã được duyệt" / "Giải thưởng đã hiện trên hồ sơ của bạn."; needs_info "Giải thưởng cần bổ sung" / "Xem ghi chú và gửi lại minh chứng."; rejected "Giải thưởng chưa được duyệt" / "Xem lý do trong mục Giải thưởng."; revoked "Giải thưởng đã bị thu hồi" / "Xem lý do trong mục Giải thưởng."
   - `artist_granted`: "Bạn đã lên hạng Nhiếp ảnh gia" / "Hồ sơ của bạn có dấu Nhiếp ảnh gia từ hôm nay."; `artist_revoked`: "Hạng Nhiếp ảnh gia đã thay đổi" / "Hồ sơ của bạn hiện là Cá nhân. Xem chi tiết trong mục Giải thưởng."
   - `chat_message`: count 1 "{sender}" / preview (text: first 80 graphemes; image "Đã gửi một ảnh"; location "Đã gửi một vị trí"); count n "{sender}" / "{n} tin nhắn mới". System messages never notify.
   - `{day}` is "T7 12/10" (Vietnamese weekday short + d/M, Asia/Ho_Chi_Minh), `{start}` "15:30".
3. **Targets** are app paths that exist in the router (the spec's `/bookings/:id`, `/work`, `/u/:uid/badges` are mapped onto the real routes): booking types → `/b/{id}`; `booking_request` → `/bookings` (Work tab, S06.01, as §3h.2 says); `review_new` → `/u/{photographerId}?tab=reviews` (S09.01 has no reviews; S03.01's Đánh giá tab is the "hồ sơ của mình" view); `badge_new` → `/u/{uid}/badges`; award types → `/me/awards`; `chat_message` → `/chat/{chatId}`. The app opens only targets matching an allowlist (`/b/:id`, `/chat/:id`, `/u/:uid`, `/u/:uid?tab=reviews`, `/u/:uid/badges`, `/me/awards`, `/bookings`, `/notifications`); anything else shows "Nội dung này không còn".
4. **Deterministic ids and grouping.** `notify` takes a `dedupeKey`; the row id is `n_{dedupeKey}` with `:` → `_` (e.g. `n_booking_accepted_{bookingId}`, `n_shoot_reminder_{bookingId}_h2`, `n_badge_new_{badgeId}_{yyyymmdd}`). In one transaction: row exists → `'duplicate'` (no push). Grouped types use id `g_{groupKey}` (`chat:{chatId}` → `g_chat_{chatId}`): existing row → `count + 1`, `actors` = new actor first, unique, ≤ 3, re-rendered title/body, `createdAt = now`, `readAt = null`, `lastEventId`; an event whose id equals `lastEventId` is `'duplicate'`. Push is sent only for `'created'`/`'grouped'`, after commit, best-effort. When the in-app channel is off nothing is stored, so a retried trigger may push twice (accepted, ledgered).
5. **`unreadCount`.** Never incremented by hand. Trigger `onNotificationWrite` (`users/{uid}/notifications/{id}`) runs `reconcileUnread(uid)`: `count(readAt == null)` (rows are always created with `readAt: null`), then writes `users/{uid}.unreadCount` and `unreadCountAt` in a transaction **only if** its count time is newer than the stored `unreadCountAt`. Idempotent under retries and safe against out-of-order triggers. `markAllNotificationsRead` sets `readAt` on every unread row (pages of 400) and writes `unreadCount: 0` the same way.
6. **Delivery decision** (pure `decideDelivery(type, prefs, now)`): `inbox = critical || channels[category].inApp`; `push = channels[category].push ? (quiet(now) && !critical ? 'quiet' : 'default') : 'none'`; `shoot_reminder` is dropped entirely when `reminders.h24`/`h2` (its variant) is off. Quiet window `from`–`to` in Asia/Ho_Chi_Minh wraps midnight when `from > to`. Missing or invalid prefs doc → defaults.
7. **Locked switch.** `channels.booking.inApp` is always `true` (spec "Nhóm giao dịch quan trọng … không tắt hoàn toàn được ở cột Trong app"): the S17.02 switch is shown on and disabled with semantics "…, Trong app, luôn bật", rules refuse `false`, and booking rows offer no "Tắt loại thông báo này" (`NotificationRow.onMuteKind` becomes nullable).
8. **Hidden categories.** "Việc đăng tuyển" (jobs) and "Chụp ngay" (instant) rows are hidden behind `const kJobsEnabled = false`, `kInstantEnabled = false` in `lib/core/feature_flags.dart` (spec gates jobs explicitly; instant has no emitter either, and a switch that controls nothing misleads). When instant is on, customers see only its Push switch. Departs from the mock (which shows both rows); Task 7 notes it in the S17.02 spec.
9. **Quiet push on Android.** Two channels created natively in `MainActivity.kt` (`default`: importance high, sound; `quiet`: importance low, no sound/vibration), manifest default channel `default`; the server sends `android.notification.channelId` `quiet` or `default`. No `flutter_local_notifications`; foreground FCM messages are not shown (the inbox and the tab badge update live), which also satisfies "chat push only when the app is in the background".
10. **Devices.** `devices/{uid}_{installId}` `{userId, provider: 'fcm', token, platform, lastSeenAt}` (shape and rules from plan I4, written here first; I4 reuses `lib/data/push/`). Registered only while the OS permission is granted; on token refresh re-registered; before sign-out the doc is deleted (best-effort, 3 s timeout). Server: `onDeviceWrite` deletes other device docs with the same token (another account signed in on the same phone); the FCM sender deletes docs whose token is `registration-token-not-registered`/`invalid-registration-token`. In the Functions emulator (`FUNCTIONS_EMULATOR === 'true'`) the sender only logs.
11. **Chat rows clear with the chat.** Trigger `onChatMemberWrite` (`chats/{chatId}/members/{uid}`): when `unreadCount` becomes 0, set `readAt` on `users/{uid}/notifications/g_chat_{chatId}` if it is unread. No feature code in the chat screens.
12. **S09.01 summary without a second listener.** `latestNotificationProvider` is a one-shot `get` (limit 1) re-run when `unreadCountProvider` changes; it never listens. The row shows the newest title, or "Chưa có thông báo nào" when empty.
13. **Reminders.** `bookingClock` (every 15 min) also runs `sendDueReminders`: bookings with status `upcoming` (exist only within 24 h of start); `h24` when `start − now ∈ (20 h, 24 h]`, `h2` when `start − now ∈ (0, 2 h]`; both parties; ids per Decision 4 make repeats harmless. A booking accepted less than 20 h before start gets only `h2`.
14. **Badge catalogue** (domain `BADGE_CATALOG`; synced to `badges/{id}` by the seed and by the nightly `reconcileBadges`; the evaluator never reads Firestore for it). 12 badges, matching the mock's "5 / 12" and "2 / 3", "3 / 9":

   | id | source | audience | name (shortName) | description = locked condition | rule | progress | revocable | icon |
   |---|---|---|---|---|---|---|---|---|
   | `top_rated` | review | photographer | Được đánh giá cao | Từ 4,8 sao với ít nhất 20 đánh giá | `rating >= 4.8`, minSample `reviewCount >= 20` | reviewCount / 20 | ✓ | favorite |
   | `punctual` | review | photographer | Khen đúng giờ | 5 đánh giá khen đúng giờ | `punctualMentions >= 5` | ✓ | – | schedule |
   | `detailed_reviewer` | review | customer | Nhận xét chi tiết | Viết 5 nhận xét dài | `detailedReviews >= 5` | ✓ | – | check |
   | `new_member` | system | both | Thành viên mới | 30 ngày đầu trên app | `accountAgeDays <= 30` | none; hidden when not held | ✓ | celebration |
   | `complete_profile` | system | photographer | Hồ sơ đầy đủ | Đủ ảnh và gói | `workPosts >= 6`, minSample `activeServices >= 1` | workPosts / 6 | – | person |
   | `fast_reply` | system | photographer | Phản hồi nhanh | Trả lời trong 1 giờ | `responseMinutes <= 60` (absent = not met) | none | ✓ | chat_bubble |
   | `shoots_10`, `shoots_50`, `shoots_100` | system | photographer | 10 / 50 / 100+ buổi chụp ("10 buổi", "50 buổi", "100+ buổi") | Hoàn thành {10/50/100} buổi chụp | `completedShoots >= n` | ✓ | – | photo_camera |
   | `event_host` | system | photographer | Chủ sự kiện | Tổ chức 1 sự kiện | `hostedEvents >= 1` | ✓ | – | calendar_today |
   | `loyal_customer` | system | customer | Khách thân thiết | Hoàn thành 3 buổi chụp | `customerShoots >= 3` | ✓ | – | favorite |
   | `sharer` | system | customer | Người chia sẻ | Chia sẻ 5 bài Buổi chụp thật | `realShootPosts >= 5` | ✓ | – | ios_share |

   Earned snapshot text (`snapshot.text`, shown instead of the condition on earned tiles, mock "4,9 sao từ 58 đánh giá", "Hoàn thành 112 buổi"): `top_rated` "{rating} sao từ {count} đánh giá"; `shoots_*` "Hoàn thành {n} buổi"; others the description. Order = table order (`order` 10, 20, …).
15. **Metrics** (port `BadgeMetricsReader.read(uid, metrics)`; Firestore adapter): `rating`, `reviewCount`, `responseMinutes`, `punctualMentions` from `photographers/{uid}.stats`; `punctualMentions` is a new counter added by `countReview` in the same transaction when the review text contains "đúng giờ" (case/diacritic-insensitive match on "dung gio" after folding); `detailedReviews` = reviews `where customerId == uid` (limit 100) with text ≥ 50 graphemes; `completedShoots` = `count()` of bookings `photographerId == uid, status in [completed, reviewed]`; `customerShoots` same by `customerId`; `workPosts` = `count()` posts `photographerId == uid, kind == 'work'`; `realShootPosts` = `count()` posts `authorId == uid, kind == 'real_shoot'`; `activeServices` = `count()` `photographers/{uid}/services where active == true`; `hostedEvents` = `count()` events `host.id == uid, status == 'completed'`; `accountAgeDays` from `users/{uid}.createdAt`. Only metrics of eligible badges are read.
16. **Who is evaluated when** (`evaluateUserBadges(uid)`, idempotent): user doc created (`new_member`); review counted (photographer and customer); booking → `completed` (both parties); post created (author); service written (owner); `photographers/{uid}.stats.responseMinutes` changed (in the `onPhotographerWrite` wrapper). Nightly `reconcileBadges` (03:30 Asia/Ho_Chi_Minh): upsert catalogue docs that differ, then re-evaluate holders of `new_member` older than 30 days (collection-group query on `badges` `badgeId == 'new_member' && awardedAt < cutoff`, so each earned doc stores `badgeId` and `uid`). Audience: users whose `role` is photographer (or who have a `photographers/{uid}` doc) are evaluated for photographer + customer + both; others for customer + both.
17. **S03.02 rules.** Own view shows the catalogue badges of the user's audiences (Decision 16), earned first by `order` within each section, locked ones dimmed with `CapacityBar` when a progress entry exists; `new_member` is hidden when not held. Header "{earned} / {shown}"; section headers "{earned} / {shown}". Others see earned only, no header counts, no progress; empty → `EmptyState` "Chưa có huy hiệu nào". Own view with nothing earned shows a card "Gần đạt nhất: {name} · {cur} / {target}" (highest `current/target`) above the grid. Tap a tile → sheet with name, description, and "Đạt ngày {d/M/yyyy}" or the progress line.
18. **"Mới" dot.** SharedPreferences `badgesSeenAt:<uid>` (UTC ms). On the own S03.02, tiles with `awardedAt > seenAt` show `isNew`; after the first frame with data the screen writes `seenAt = now`, so the dots stay for this visit and are gone on the next. Never shown on others' profiles.
19. **Primer moments now.** Customer: S05.02 opened with `?paid=1` (deposit done, booking `requested`) → context `customerBooking(photographerName)`. Photographer: right after a successful accept (S05.02 action or S06.01 `_accept`), before navigating → context `photographer`. Ticket purchase, instant request and Live Shutter call the same `maybeAskForNotifications` in their own plans. "Nhận booking đầu tiên" is read as accepting (the user's action), not the arrival of a request.
20. **Badge chip rows.** S03.01 (after the bio, before the tabs, mock `#S03.01`) and S09.01 (below the "Thông báo" row): `BadgeRow(max: 3, onSeeAll → /u/{uid}/badges)` of earned badges by `order`, chip label = `shortName ?? name`; hidden when the user has none (S09.01 own view shows "Tất cả" alone so S03.02 stays reachable). No `BadgeRow` on `PhotographerCard` yet (needs badges in `PhotographerSummary`; ledger).
21. **No Postgres migration.** The self-hosted API has no notification or badge routes yet; Task 7 updates the target DDL docs only (`notifications` gains `tab`, `category`, `target`, `group_key`, `actors jsonb`, `count`, `thumb_url`; new `notification_prefs`; Firestore path mapping `users/{uid}/notifications/{id}`). No retention/pruning of old rows in v1 (ledger).
22. **Analytics** go through a no-op hook `notificationsAnalyticsProvider` (pattern of `skills_analytics.dart`) with the event names of the specs; parameters never hold notification text.

### Controller rulings on the owner items (2026-10-06, single session; owner may revise)

- **R1 `unreadCount` is private.** It lives in `users/{uid}/private/inbox` (`{unreadCount, lastReadAt}`), owner-read only, server-written; not on the public `users/{uid}` doc (privacy wins over the spec's placement). Every task that mentions `users/{uid}.unreadCount` uses this doc instead; the rules test asserts another user cannot read it; update `data-model/domain-model.md` and the main spec line in Task 7's docs step.
- **R2 Inbox pruning.** The nightly job deletes read inbox rows older than 90 days (Task 1 use case + Task 3 scheduled function, test it).
- **R3** S17.02 "Việc đăng tuyển" / "Chụp ngay" rows stay behind flags until those features exist (as the plan says).
- **R4** Server-rendered copy: mock wording where it exists, otherwise the plan's wording; all strings live in one domain table so the owner can review them in one place.

## Review Focus

1. A retried or out-of-order trigger never double-counts: two `booking_accepted` events for one booking → one row, one push; unread count stays exact after mixed creates and read marks. Pinned by Task 1 ("a duplicate dedupe key writes nothing and does not push", "an older count never overwrites a newer one") and Task 3 integration ("a retried booking trigger leaves one row", "unreadCount follows reads").
2. Prefs are honoured on the server: in-app off → no row; push off → no FCM; quiet hours → `quiet` channel except critical types; reminders off → nothing. Pinned by Task 1 delivery tests.
3. A tampered client cannot write rows, change `unreadCount`, un-read a row, edit other fields, turn `booking.inApp` off, or read someone else's progress/prefs/devices. Pinned by Task 3 rules tests.
4. S17.01 holds exactly one listener (first page, current tab) and drops it on leave; read marks are batched once per ~1 s and flushed on dispose. Pinned by Task 5 ("one listener while open, none after pop", "three taps in a second write one batch", "leaving flushes pending marks").
5. The primer never shows at app start, within 7 days of "Để sau", when granted, or when permanently denied; the FCM token is registered only after a grant. Pinned by Task 6 and Task 4 ("no token registration while not granted").
6. Others never see locked badges or progress; the "Mới" dot clears on the next visit only. Pinned by Task 7 and Task 3 rules ("progress is owner-only").
7. Deep links: only allowlisted targets navigate; a deleted booking target shows "Nội dung này không còn". Pinned by Task 5 ("unknown target is not opened", "gone booking shows the snack bar").

---

## File Structure

| File | Responsibility |
|---|---|
| `packages/domain/src/notification.ts`, `notification_render.ts`, `notification_ports.ts`, `memory_notification_store.ts`, `notification_use_cases.ts`, `booking_notifications.ts` (create); `review_stats.ts`, `index.ts` (modify) | type table, prefs, delivery, copy, notify/markAll/reconcile, booking mapping, reminders; `punctualMentions` |
| `packages/domain/src/badge.ts`, `badge_ports.ts`, `memory_badge_store.ts`, `badge_use_cases.ts` (create) | catalogue, evaluator, use cases |
| `packages/domain/test/notification*.test.ts`, `booking_notifications.test.ts`, `badge*.test.ts`, `review_stats.test.ts` (extend) | tests |
| `app_flutter/firebase/functions/src/infra/notification_firestore.ts`, `fcm_push.ts`, `user_directory.ts`, `live_notification.ts`, `badge_firestore.ts`, `live_badge.ts` (create) | adapters |
| `functions/src/callables/notification.ts`; `src/triggers/notification_write.ts`, `chat_message_created.ts`, `chat_member_write.ts`, `device_write.ts`, `user_created.ts`, `service_write.ts`; `src/scheduled/reconcile_badges.ts` (create) | callables, triggers, cron |
| `functions/src/triggers/booking_write.ts`, `review_write.ts`, `post_created.ts`, `scheduled/booking_clock.ts`, `infra/live_award.ts`, `infra/review_firestore.ts`, `src/index.ts`, `seed/fixtures.ts`, `seed/README.md` (modify) | wiring |
| `functions/test/unit/notification_*.test.ts`, `badge_*.test.ts`; `test/integration/notification.test.ts`, `badge.test.ts` | tests |
| `app_flutter/firebase/firestore.rules`, `firestore.indexes.json`, `rules-test/rules.test.mjs` (modify) | rules, indexes |
| `app_flutter/pubspec.yaml`/`.lock`, `android/app/src/main/AndroidManifest.xml`, `android/app/src/main/kotlin/com/thanhbk/photobooking/MainActivity.kt` (modify) | deps, permission, channels |
| `app_flutter/lib/data/notifications/app_notification.dart`, `notification_prefs.dart`, `notification_repository.dart`, `firestore_notification_repository.dart`, `notification_prefs_repository.dart`, `firestore_notification_prefs_repository.dart`, `notification_providers.dart` (create) | inbox + prefs data |
| `app_flutter/lib/data/push/push_messaging.dart`, `firebase_push_messaging.dart`, `notification_permission.dart`, `permission_handler_notification_permission.dart`, `device_registry.dart`, `firestore_device_registry.dart`, `prefs_primer_store.dart`, `push_providers.dart` (create) | platform ports + adapters |
| `app_flutter/lib/data/badges/badge.dart`, `badge_repository.dart`, `firestore_badge_repository.dart`, `badges_seen_store.dart`, `badge_providers.dart` (create) | badges data |
| `app_flutter/lib/core/widgets/notification_row.dart`, `permission_primer.dart`, `tab_badge.dart`, `badge_chip.dart` (modify); `notification_bell.dart` + test (delete); `lib/core/feature_flags.dart` (create); `core.dart` | core changes |
| `app_flutter/lib/features/notifications/notifications_screen.dart`, `notifications_controller.dart`, `notification_visuals.dart`, `notification_targets.dart`, `push_open_handler.dart`, `notification_settings_screen.dart`, `notification_settings_controller.dart`, `notification_primer.dart`, `notifications_analytics.dart` (create) | S17.01–S17.03 |
| `app_flutter/lib/features/badges/badges_screen.dart`, `badges_view.dart` (create) | S03.02 |
| `features/shell/placeholder_tabs.dart`, `tab_badges.dart`, `tab_shell.dart`, `features/settings/settings_screen.dart`, `features/photographer_profile/widgets/profile_header.dart`, `features/booking/booking_detail_screen.dart`, `features/work/work_screen.dart`, `lib/app/router.dart`, `lib/main.dart`, `lib/l10n/app_vi.arb` (modify) | entry points, routes, strings |
| `test/support/notifications_world.dart`, `badges_world.dart`, `fake_push.dart` (create) | test worlds |
| docs: main spec §3h/§2 status, `screens/account.md`, `shared-components.md`, `data-model/*`, `scripts/tools/build_ui_components.py` → `docs/design/ui-components.html` | docs in step |

---

### Task 1: Domain — notifications

**Files:**
- Create: `packages/domain/src/notification.ts`, `notification_render.ts`, `notification_ports.ts`, `memory_notification_store.ts`, `notification_use_cases.ts`, `booking_notifications.ts`; modify `src/index.ts`
- Test: `packages/domain/test/notification.test.ts`, `notification_render.test.ts`, `notification_use_cases.test.ts`, `booking_notifications.test.ts`

**Interfaces:**
- Produces:

```ts
export const NOTIFICATION_CATEGORIES = ['booking', 'jobs', 'instant', 'events', 'chat', 'badges', 'promo'] as const;
export type NotificationCategory = (typeof NOTIFICATION_CATEGORIES)[number];
export const NOTIFICATION_TABS = ['activity', 'events', 'system'] as const;
export type NotificationTab = (typeof NOTIFICATION_TABS)[number];
export const NOTIFICATION_TYPES = { booking_request: { category: 'booking', tab: 'activity', critical: false }, /* … Decision 1 … */ } as const;
export type NotificationType = keyof typeof NOTIFICATION_TYPES;

export interface ChannelPrefs { readonly push: boolean; readonly inApp: boolean; }
export interface NotificationPrefs {
  readonly channels: Readonly<Record<NotificationCategory, ChannelPrefs>>;
  readonly quietHours: { readonly enabled: boolean; readonly from: string; readonly to: string };   // "HH:mm"
  readonly reminders: { readonly h24: boolean; readonly h2: boolean };
}
export const DEFAULT_NOTIFICATION_PREFS: NotificationPrefs;
/** Lenient: unknown keys ignored, missing/invalid parts fall back to defaults, booking.inApp forced true. */
export function prefsFromRaw(raw: unknown): NotificationPrefs;
export function isQuietAt(prefs: NotificationPrefs, now: Date): boolean;            // Asia/Ho_Chi_Minh, wraps midnight
export interface Delivery { readonly inbox: boolean; readonly push: 'none' | 'default' | 'quiet'; }
export function decideDelivery(type: NotificationType, prefs: NotificationPrefs, now: Date, reminder?: 'h24' | 'h2'): Delivery;

// notification_render.ts — discriminated union, one member per emitted type (Decision 2)
export type NotificationContent =
  | { type: 'booking_request'; customer: string; service: string; day: string; start: string }
  | { type: 'booking_accepted'; photographer: string; day: string; start: string; place: string }
  | { type: 'booking_declined'; reason: 'declined' | 'expired'; photographer: string; percent: number }
  | { type: 'booking_cancelled'; by: 'party' | 'system'; name: string; day: string; start: string; percent: number | null }
  | { type: 'refund_done'; amount: number; bookingId: string }
  | { type: 'shoot_reminder'; hours: 24 | 2; service: string; counterpart: string; day: string; start: string }
  | { type: 'review_new'; customer: string; rating: number; text: string }
  | { type: 'badge_new'; name: string; description: string }
  | { type: 'award_reviewed'; status: 'approved' | 'needs_info' | 'rejected' | 'revoked' }
  | { type: 'artist_granted' } | { type: 'artist_revoked' }
  | { type: 'chat_message'; sender: string; preview: string; count: number };
export function renderNotification(c: NotificationContent): { title: string; body: string };
export function formatDayShortVi(day: string): string;   // '2026-10-12' → 'T2 12/10'
export function formatVnd(amount: number): string;       // 450000 → '450.000₫'

// notification_ports.ts
export interface NotificationActor { readonly id: string; readonly name: string; readonly avatarUrl: string | null; }
export interface NotificationRow {
  readonly id: string; readonly userId: string; readonly type: NotificationType; readonly tab: NotificationTab;
  readonly category: NotificationCategory; readonly title: string; readonly body: string; readonly target: string;
  readonly groupKey: string | null; readonly actors: readonly NotificationActor[]; readonly count: number;
  readonly thumbUrl: string | null; readonly lastEventId: string | null; readonly createdAt: Date; readonly readAt: Date | null;
}
export interface NotificationTx { getRow(uid: string, id: string): Promise<NotificationRow | null>; putRow(r: NotificationRow): void; }
export interface NotificationStore {
  runTransaction<T>(fn: (tx: NotificationTx) => Promise<T>): Promise<T>;
  getPrefs(uid: string): Promise<unknown>;                                    // raw doc or null
  listUnreadIds(uid: string, limit: number): Promise<string[]>;
  markRead(uid: string, ids: readonly string[], at: Date): Promise<void>;
  countUnread(uid: string): Promise<number>;
  /** Writes users/{uid}.unreadCount + unreadCountAt only when `at` is newer than the stored unreadCountAt. */
  setUnreadCount(uid: string, count: number, at: Date): Promise<boolean>;
}
export interface PushMessage {
  readonly title: string; readonly body: string; readonly channel: 'default' | 'quiet';
  readonly data: { readonly type: string; readonly target: string; readonly notificationId?: string };
}
export interface PushSender { send(uid: string, msg: PushMessage): Promise<void>; }     // adapter finds devices, prunes dead tokens
export interface UserDirectory { get(uid: string): Promise<{ name: string; avatarUrl: string | null } | null>; }
export interface NotifyDeps { readonly store: NotificationStore; readonly push: PushSender; readonly users: UserDirectory; readonly clock: Clock; }

export interface NotifyRequest {
  readonly userId: string; readonly content: NotificationContent; readonly target: string;
  readonly dedupeKey: string;             // ignored for grouped requests
  readonly groupKey?: string; readonly eventId?: string;  // grouped (chat)
  readonly actor?: NotificationActor; readonly thumbUrl?: string | null; readonly reminder?: 'h24' | 'h2';
}
export function notify(deps: NotifyDeps, req: NotifyRequest): Promise<'created' | 'grouped' | 'duplicate' | 'suppressed'>;
export function markAllRead(deps: NotifyDeps, uid: string): Promise<number>;           // rows marked
export function reconcileUnread(deps: NotifyDeps, uid: string): Promise<number>;

// booking_notifications.ts
export interface BookingNotice { readonly to: 'customer' | 'photographer'; readonly kind: 'request' | 'accepted' | 'declined' | 'expired' | 'cancelled' | 'refund'; }
export function bookingNotices(before: Booking | null, after: Booking | null): BookingNotice[];   // pure
export function notifyBookingChange(deps: NotifyDeps, before: Booking | null, after: Booking | null): Promise<void>;
export function dueReminders(bookings: readonly Booking[], now: Date): { booking: Booking; variant: 'h24' | 'h2' }[];  // Decision 13
export function sendDueReminders(deps: NotifyDeps, bookings: readonly Booking[]): Promise<number>;
```

Behaviour notes:
- `bookingNotices`: `draft→requested` → photographer `request`; `requested→accepted` → customer `accepted`; `requested→declined` → customer `declined`; `requested→expired` → customer `expired`; `*→cancelled` → the party that did not cancel (`cancel.by`), both when `system`; refund when `depositRefundedAt` goes from absent to set and `depositRefunded > 0`; creation/deletion, `accepted→upcoming`, `upcoming→completed` and `completed→reviewed` → none. Dedupe keys `booking_{kind}_{bookingId}` (refund `refund_done_{bookingId}`, cancel `booking_cancelled_{bookingId}_{to}`).
- `notifyBookingChange` resolves names with `UserDirectory` (missing → "Khách hàng" / "Nhiếp ảnh gia"), sets `thumbUrl` to the counterpart's avatar, and never throws for one failed recipient (each `notify` is awaited in `Promise.allSettled`; failures rethrown as one error after both ran, so the trigger retries and duplicates are skipped by id).
- `notify` order: render → read prefs → `decideDelivery`; `inbox == false && push == 'none'` → `'suppressed'`; transaction (dedupe/group) → after commit `push.send` (errors swallowed and reported to an optional `onPushError`); `push` carries `notificationId` only when a row exists.

Grouped write (easy to get wrong):

```ts
const id = `g_${req.groupKey!.replace(/:/g, '_')}`;
const prev = await tx.getRow(req.userId, id);
if (prev && req.eventId && prev.lastEventId === req.eventId) return 'duplicate';
const count = (prev?.count ?? 0) + 1;
const actors = [req.actor!, ...(prev?.actors ?? []).filter((a) => a.id !== req.actor!.id)].slice(0, 3);
const text = renderNotification({ ...req.content, count } as NotificationContent);
tx.putRow({ ...base, id, count, actors, ...text, createdAt: now, readAt: null, lastEventId: req.eventId ?? null });
return prev ? 'grouped' : 'created';
```

- [ ] **Step 1: Contract check** (domain/Functions part of "Contract with existing code").
- [ ] **Step 2: Write the failing tests:**
  - `notification.test.ts`: "every type has a category, tab and critical flag"; "defaults: all on, promo off, quiet 22:00–07:00 on, reminders on"; "prefsFromRaw keeps valid parts and forces booking.inApp true"; "garbage prefs give defaults"; "quiet window wraps midnight in Vietnam time" (23:30 VN quiet, 07:30 VN not, 15:00 UTC = 22:00 VN quiet); "disabled quiet hours are never quiet"; "in-app off and not critical → no inbox"; "critical keeps the inbox and the default channel at night"; "push off → none"; "quiet hours → quiet channel"; "reminder variant off drops the reminder".
  - `notification_render.test.ts`: one test per Decision 2 line ("booking_accepted matches the mock row", "refund_done shows 450.000₫ and #A0C2", "review excerpt stops at 80 graphemes with an ellipsis", "chat count 3 reads '3 tin nhắn mới'", "award statuses each have a title"); "formatDayShortVi gives T7 10/10 for 2026-10-10 and CN 11/10 for 2026-10-11"; "formatVnd groups thousands with dots".
  - `notification_use_cases.test.ts`: "creates a row with readAt null and pushes with its id"; "a duplicate dedupe key writes nothing and does not push"; "in-app off still pushes without a notification id"; "everything off is suppressed"; "grouped events bump count, move to the top and become unread"; "the same event id twice is a duplicate"; "group keeps at most 3 unique actors, newest first"; "a push failure does not undo the row"; "markAllRead marks every unread row and sets the count to 0"; "reconcileUnread writes the counted value"; "an older count never overwrites a newer one".
  - `booking_notifications.test.ts`: "deposit paid notifies the photographer"; "accept notifies the customer"; "decline and expiry notify the customer with the refund percent"; "a customer cancel notifies the photographer only"; "a system cancel notifies both"; "refund once when depositRefundedAt appears"; "upcoming, completed and reviewed send nothing"; "a retried change is a duplicate"; "dueReminders: 23 h before → h24, 90 min before → h2, 19 h before → nothing (h24 skipped, h2 later)".
- [ ] **Step 3: Run** `(cd packages/domain && npm test)` → fail. **Step 4: Implement.** **Step 5: Run** `npm test && npm run lint` → pass.
- [ ] **Step 6: Commit** `feat(domain): notifications — types, prefs, delivery, copy, notify and booking notices [10a]`.

### Task 2: Domain — badges

**Files:**
- Create: `packages/domain/src/badge.ts`, `badge_ports.ts`, `memory_badge_store.ts`, `badge_use_cases.ts`; modify `review_stats.ts` (`punctualMentions`), `src/index.ts`
- Test: `packages/domain/test/badge.test.ts`, `badge_use_cases.test.ts`; extend `review_stats.test.ts`

**Interfaces:**
- Produces:

```ts
export const BADGE_METRICS = ['rating', 'reviewCount', 'punctualMentions', 'detailedReviews', 'accountAgeDays', 'workPosts',
  'activeServices', 'responseMinutes', 'completedShoots', 'hostedEvents', 'customerShoots', 'realShootPosts'] as const;
export type BadgeMetric = (typeof BADGE_METRICS)[number];
export interface BadgeRule { readonly metric: BadgeMetric; readonly op: '>=' | '<='; readonly threshold: number;
  readonly minSample?: { readonly metric: BadgeMetric; readonly threshold: number } }
export interface BadgeDefinition {
  readonly id: string; readonly name: string; readonly shortName: string | null; readonly description: string;
  readonly icon: string; readonly source: 'review' | 'system'; readonly audience: 'photographer' | 'customer' | 'both';
  readonly order: number; readonly rule: BadgeRule; readonly progress: 'none' | 'metric' | 'minSample';
  readonly revocable: boolean; readonly hiddenWhenLocked: boolean;
}
export const BADGE_CATALOG: readonly BadgeDefinition[];       // Decision 14
export type Metrics = Partial<Record<BadgeMetric, number | null>>;   // null/absent = unknown → rule not met
export function meets(rule: BadgeRule, m: Metrics): boolean;
export function progressOf(b: BadgeDefinition, m: Metrics): { current: number; target: number } | null;  // current capped at target
export function snapshotText(b: BadgeDefinition, m: Metrics): string;
export function eligibleBadges(isPhotographer: boolean): readonly BadgeDefinition[];
export interface BadgePlan { readonly award: readonly BadgeDefinition[]; readonly revoke: readonly string[];
  readonly progress: Readonly<Record<string, { current: number; target: number }>> }
export function planBadges(eligible: readonly BadgeDefinition[], m: Metrics, earned: ReadonlySet<string>): BadgePlan;

// badge_ports.ts
export interface EarnedBadge { readonly badgeId: string; readonly awardedAt: Date; readonly snapshotText: string; }
export interface BadgeTx {
  listEarned(uid: string): Promise<EarnedBadge[]>;
  putEarned(uid: string, b: EarnedBadge): void;                 // users/{uid}/badges/{badgeId} {badgeId, uid, awardedAt, snapshot:{text}}
  deleteEarned(uid: string, badgeId: string): void;
  setProgress(uid: string, p: BadgePlan['progress'], at: Date): void;   // overwrite users/{uid}/private/badgeProgress
}
export interface BadgeStore {
  runTransaction<T>(fn: (tx: BadgeTx) => Promise<T>): Promise<T>;
  holdersOlderThan(badgeId: string, cutoff: Date, limit: number): Promise<string[]>;
  syncCatalog(defs: readonly BadgeDefinition[]): Promise<number>;      // writes only changed docs
}
export interface BadgeMetricsReader {
  isPhotographer(uid: string): Promise<boolean>;
  read(uid: string, metrics: ReadonlySet<BadgeMetric>): Promise<Metrics>;
}
export interface BadgeDeps { readonly badges: BadgeStore; readonly metrics: BadgeMetricsReader; readonly notify: NotifyDeps; readonly clock: Clock; }

export function evaluateUserBadges(deps: BadgeDeps, uid: string): Promise<{ awarded: string[]; revoked: string[] }>;
export function reconcileBadges(deps: BadgeDeps): Promise<{ catalogWrites: number; reevaluated: number }>;
// review_stats.ts
export function mentionsPunctual(text: string): boolean;   // fold diacritics, lower-case, contains 'dung gio'
// PhotographerStatsPatch gains `punctualMentions: number`; countReview adds 1 when mentionsPunctual(review.text)
```

Rules: a badge already earned and not `revocable` is never removed; a revocable one is removed when `meets` turns false; award writes `snapshotText` at award time and keeps it (no rewrite on later evaluations). `evaluateUserBadges` reads metrics outside the transaction, then in one transaction re-reads earned badges, applies the plan, writes progress for every eligible badge with `progress != 'none'` that is not earned; after commit sends `badge_new` (dedupe `badge_new_{id}_{yyyymmdd}`, target `/u/{uid}/badges`) for each award, best-effort.

- [ ] **Step 1: Write the failing tests:**
  - `badge.test.ts`: "catalogue has 12 badges, 3 from reviews and 9 system, unique ids and orders"; "top_rated needs 20 reviews even at 5 stars"; "top_rated progress counts reviews toward 20"; "unknown responseMinutes never meets fast_reply"; "shoots progress caps at the target"; "customers are not eligible for photographer badges"; "planBadges awards newly met badges"; "planBadges revokes only revocable badges"; "planBadges never revokes shoots_10"; "progress is omitted for earned and for progress 'none'"; "snapshot for top_rated reads '4,9 sao từ 58 đánh giá'".
  - `badge_use_cases.test.ts`: "a new user gets new_member and a badge_new notification"; "a second evaluation awards nothing and sends nothing"; "a dropped rating removes top_rated"; "progress is written for locked badges only"; "a failed notify does not undo the award"; "reconcile syncs changed catalogue docs only"; "reconcile removes new_member after 30 days".
  - `review_stats.test.ts` (extend): "a review praising 'Đúng giờ' bumps punctualMentions"; "'dung gio' without diacritics also counts"; "a counted review is not counted twice".
- [ ] **Step 2: Run** → fail. **Step 3: Implement.** **Step 4: Run** `npm test && npm run lint` → pass.
- [ ] **Step 5: Commit** `feat(domain): badge catalogue, evaluator and reconcile [10a]`.

### Task 3: Functions, rules, indexes, seed

**Files:**
- Create: `functions/src/infra/notification_firestore.ts` (`FirestoreNotificationStore`, row ↔ doc mapping), `fcm_push.ts` (`FcmPushSender`, `LoggingPushSender`), `user_directory.ts`, `live_notification.ts` (`liveNotifyDeps()`), `badge_firestore.ts` (`FirestoreBadgeStore`, `FirestoreBadgeMetricsReader`), `live_badge.ts`; `src/callables/notification.ts`; `src/triggers/notification_write.ts`, `chat_message_created.ts`, `chat_member_write.ts`, `device_write.ts`, `user_created.ts`, `service_write.ts`; `src/scheduled/reconcile_badges.ts`
- Modify: `src/triggers/booking_write.ts` (after chat sync: `notifyBookingChange`, and `evaluateUserBadges` for both parties on `→ completed`), `review_write.ts` (replace the no-op with `review_new` + evaluate photographer and customer), `post_created.ts` (evaluate the author), `scheduled/booking_clock.ts` (`sendDueReminders` over `status == 'upcoming'`, limit 200), `infra/live_award.ts` (`notify.tierChanged` → `artist_granted`/`artist_revoked`, `awardReviewed` → `award_reviewed`, dedupe `award_reviewed_{awardId}_{status}`, `artist_{to}_{yyyymmdd}`), `infra/review_firestore.ts` (persist `punctualMentions`), `src/index.ts`, `seed/fixtures.ts`, `seed/README.md`
- Modify: `app_flutter/firebase/firestore.rules`, `firestore.indexes.json`, `rules-test/rules.test.mjs`
- Test: `test/unit/notification_mapping.test.ts`, `notification_callables.test.ts`, `fcm_push.test.ts`, `badge_metrics.test.ts`; `test/integration/notification.test.ts`, `badge.test.ts`

**Interfaces:**
- Produces: callable `markAllNotificationsRead({}) → {marked}`; triggers `onNotificationWrite` (`users/{uid}/notifications/{id}`), `onChatMessageCreated` (`chats/{chatId}/messages/{messageId}`, skips `type == 'system'`, notifies the other member, `groupKey chat:{chatId}`, `eventId = messageId`), `onChatMemberWrite` (`chats/{chatId}/members/{uid}`, Decision 11), `onDeviceWrite` (`devices/{id}`, Decision 10), `onUserCreated` (`users/{uid}`), `onServiceWrite` (`photographers/{uid}/services/{serviceId}`); schedule `reconcileBadges` (`schedule: '30 3 * * *'`, `timeZone: 'Asia/Ho_Chi_Minh'`, region, `maxInstances: 1`); `onPhotographerWrite` wrapper calls `evaluateUserBadges` when `stats.responseMinutes` changed.
- Firestore shapes:
  - `users/{uid}/notifications/{id}`: `type, tab, category, title, body, target, groupKey|null, actors[{id,name,avatarUrl}], count, thumbUrl|null, lastEventId|null, createdAt, readAt (null)`.
  - `users/{uid}`: `unreadCount`, `unreadCountAt` (server only).
  - `users/{uid}/private/notification_prefs`: `channels{cat:{push,inApp}}, quietHours{enabled,from,to}, reminders{h24,h2}, updatedAt`.
  - `users/{uid}/badges/{badgeId}`: `badgeId, uid, awardedAt, snapshot{text}`; `users/{uid}/private/badgeProgress`: `{entries: {badgeId: {current, target}}, updatedAt}`; `badges/{id}`: catalogue fields of Decision 14 minus `rule` internals (`name, shortName, description, icon, source, audience, order, hiddenWhenLocked, progress`).
  - `devices/{uid}_{installId}`: Decision 10.
- FCM (`fcm_push.ts`): `getMessaging().sendEachForMulticast({ tokens, notification: {title, body}, data, android: { priority: channel === 'quiet' ? 'normal' : 'high', notification: { channelId: channel } } })`; tokens from `devices where userId == uid` (limit 10); failed tokens with the two dead-token codes → delete those device docs.

Rules (sample):

```
match /users/{uid} {
  // existing read/create/update unchanged (unreadCount, unreadCountAt are not in userClientFields)
  match /private/{docId} {
    allow read: if isOwner(uid);
    allow create, update: if isOwner(uid)
      && ((docId == 'contact' && validContact(uid))
          || (docId == 'notification_prefs' && validNotificationPrefs()));
    allow delete: if false;                       // badgeProgress stays server-only
  }
  match /notifications/{id} {
    allow read: if isOwner(uid);
    allow update: if isOwner(uid) && resource.data.readAt == null
      && request.resource.data.diff(resource.data).affectedKeys().hasOnly(['readAt'])
      && request.resource.data.readAt == request.time;
    allow create, delete: if false;
  }
  match /badges/{badgeId} { allow read: if signedIn(); allow write: if false; }
}
match /badges/{badgeId} { allow read: if signedIn(); allow write: if false; }
match /devices/{deviceId} { /* plan I4 block verbatim: owner read/delete; create/update with the id pattern and fixed keys */ }

function validChannel(c) { return c is map && c.keys().hasOnly(['push', 'inApp']) && c.push is bool && c.inApp is bool; }
function validHm(s) { return s is string && s.matches('^([01][0-9]|2[0-3]):[0-5][0-9]$'); }
function validNotificationPrefs() {
  let d = request.resource.data;
  let ch = d.channels;
  return d.keys().hasOnly(['channels', 'quietHours', 'reminders', 'updatedAt'])
    && ch is map && ch.keys().hasOnly(['booking', 'jobs', 'instant', 'events', 'chat', 'badges', 'promo'])
    && validChannel(ch.booking) && ch.booking.inApp == true
    && (!('jobs' in ch) || validChannel(ch.jobs)) /* … same for instant, events, chat, badges, promo … */
    && d.quietHours is map && d.quietHours.keys().hasOnly(['enabled', 'from', 'to'])
    && d.quietHours.enabled is bool && validHm(d.quietHours.from) && validHm(d.quietHours.to)
    && d.reminders is map && d.reminders.keys().hasOnly(['h24', 'h2']) && d.reminders.h24 is bool && d.reminders.h2 is bool
    && d.updatedAt == request.time;
}
```

Indexes: `notifications` (collection) `(tab ASC, createdAt DESC)`; `bookings (customerId, status)`; `posts (photographerId, kind)`; `posts (authorId, kind)`; `events (host.id, status)`; collection group `badges` `(badgeId ASC, awardedAt ASC)` with `queryScope: COLLECTION_GROUP`.

Seed: catalogue docs (`syncCatalog(BADGE_CATALOG)`); An: `top_rated`, `shoots_10`, `complete_profile` earned + progress for `punctual` 3/5 and `shoots_50` 12/50; Lan: `loyal_customer` earned + `sharer` 2/5, `detailed_reviewer` 3/5; five inbox rows for Lan (accepted unread, reminder read, refund read, declined read 12 days old, grouped chat unread with 2 messages) and two for An (booking_request unread, review_new read), `unreadCount` set to match; no prefs doc (defaults). README: a "Notifications and badges" table.

- [ ] **Step 1: Write the failing tests.** Unit: "row doc maps to NotificationRow and back"; "unauthenticated markAll is refused"; "markAll returns the marked count"; "FCM sender uses the quiet channel and normal priority at night"; "dead tokens are deleted, others kept"; "emulator sender only logs"; "metrics reader asks only the requested metrics" (fake Firestore); "detailedReviews counts texts of 50+ graphemes". Integration (do not run): "accepting a booking creates one row for the customer"; "a retried booking trigger leaves one row"; "unreadCount follows creates and reads"; "markAllNotificationsRead zeroes the count"; "a chat message groups into g_chat_{id} and reading the chat clears it"; "in-app off writes no row"; "a counted review notifies the photographer and awards top_rated at 20 reviews"; "a new user gets new_member"; "the reminder sweep sends h2 once". Rules (do not run): "owner reads own notifications, others cannot"; "owner may set readAt once to request.time"; "readAt cannot be cleared or set twice"; "no other field of a row can change"; "nobody creates or deletes rows"; "unreadCount is not client-writable"; "prefs: owner writes a valid doc"; "prefs: booking.inApp false is refused"; "prefs: bad time string is refused"; "prefs: other users cannot read"; "badgeProgress is owner-only and not writable"; "earned badges are readable by signed-in users, never writable"; "catalogue is readable, not writable"; "devices: owner creates with the id pattern; other uid or extra keys refused".
- [ ] **Step 2: Run** `(cd app_flutter/firebase/functions && npm test)` → fail. **Step 3: Implement.** **Step 4: Run** `npm test && npm run build && npm run lint` → pass; ledger the skipped emulator suites.
- [ ] **Step 5: Commit** `feat(functions): notify adapters, FCM, unread count, booking/review/chat/award notices, badge triggers, rules [10a]`.

### Task 4: App data, platform ports and core widget changes

**Files:**
- Modify: `app_flutter/pubspec.yaml`/`.lock` (`flutter pub add firebase_messaging permission_handler` with `allowed_domains: pub.dev, storage.googleapis.com`; if pub.dev is unreachable, stop and tell the user), `android/app/src/main/AndroidManifest.xml` (`POST_NOTIFICATIONS`; `<meta-data android:name="com.google.firebase.messaging.default_notification_channel_id" android:value="default"/>`), `MainActivity.kt` (create channels `default` "Thông báo" high, `quiet` "Thông báo yên lặng" low, no sound/vibration, in `onCreate`, API 26+)
- Create: `lib/data/notifications/*`, `lib/data/push/*`, `lib/data/badges/*` (File Structure), `lib/core/feature_flags.dart`
- Modify core: `notification_row.dart`, `permission_primer.dart`, `tab_badge.dart`, `badge_chip.dart` (`badgeIconOf` gains the catalogue icon keys `favorite`, `schedule`, `check`, `celebration`, `person`, `chat_bubble`, `photo_camera`, `calendar_today`, `ios_share` → matching `AppIcons`), `core.dart`; delete `notification_bell.dart` and `test/core/widgets/notification_bell_test.dart`; gallery script tiles for the changed widgets
- Create test support: `test/support/fake_push.dart` (`FakePushMessaging`, `FakeNotificationPermission`, `FakeDeviceRegistry`), fakes `FakeNotificationRepository`, `FakeNotificationPrefsRepository`, `FakeBadgeRepository` next to their interfaces (album pattern)
- Test: `test/data/notifications/firestore_notification_repository_test.dart`, `notification_prefs_test.dart`, `test/data/push/push_registration_test.dart`, `prefs_primer_store_test.dart`, `test/data/badges/firestore_badge_repository_test.dart`, `test/core/widgets/notification_row_test.dart` (update), `permission_primer_test.dart` (update), `tab_badge_test.dart` (extend)

**Interfaces:**
- Produces:

```dart
// lib/data/notifications/app_notification.dart
enum NotificationTab { activity, events, system }            // code = name
enum NotificationCategory { booking, jobs, instant, events, chat, badges, promo }
@immutable class NotificationActor { const NotificationActor({required this.id, required this.name, this.avatarUrl}); }
@immutable class AppNotification {
  const AppNotification({required this.id, required this.type, required this.tab, required this.category, required this.title,
    required this.body, required this.target, required this.createdAt, this.readAt, this.actors = const [], this.count = 1, this.thumbUrl});
  final String id, type, title, body, target; final NotificationTab tab; final NotificationCategory category;
  final DateTime createdAt; final DateTime? readAt; final List<NotificationActor> actors; final int count; final String? thumbUrl;
  bool get unread => readAt == null;
  AppNotification markedRead(DateTime at);
}
@immutable class NotificationCursor { /* createdAt + id of the last row */ }
@immutable class NotificationPage { const NotificationPage({required this.items, this.next, this.fromCache = false}); final NotificationCursor? next; }
abstract class NotificationRepository {
  Stream<NotificationPage> watchFirstPage(String uid, {NotificationTab? tab, int limit = 30});   // live; next == null when < limit
  Future<NotificationPage> page(String uid, {NotificationTab? tab, required NotificationCursor after, int limit = 30});
  Stream<int> watchUnreadCount(String uid);                    // users/{uid}.unreadCount, 0 when absent
  Future<AppNotification?> latest(String uid);                 // one-shot, limit 1
  Future<void> markRead(String uid, Iterable<String> ids);     // one WriteBatch, readAt = serverTimestamp
  Future<void> markAllRead();                                  // callable markAllNotificationsRead
  Future<bool> targetExists(String target);                    // /b/:id and /chat/:id: one doc get; others true
}
// lib/data/notifications/notification_prefs.dart
@immutable class ChannelPrefs { const ChannelPrefs({required this.push, required this.inApp}); }
@immutable class NotificationPrefs {
  const NotificationPrefs({required this.channels, required this.quietEnabled, required this.quietFrom, required this.quietTo,
    required this.reminder24, required this.reminder2});
  static const defaults = …;                                   // Global Constraints
  factory NotificationPrefs.fromMap(Map<String, dynamic>? m);  // lenient, booking.inApp forced true
  Map<String, Object?> toMap();                                // all seven categories, without updatedAt
  NotificationPrefs withChannel(NotificationCategory c, {bool? push, bool? inApp});   // booking inApp stays true
  NotificationPrefs withQuiet({bool? enabled, String? from, String? to});
  NotificationPrefs withReminders({bool? h24, bool? h2});
}
@immutable class PrefsSnapshot { const PrefsSnapshot(this.prefs, {this.fromCache = false}); }
abstract class NotificationPrefsRepository {
  Stream<PrefsSnapshot> watch(String uid);
  Future<void> save(String uid, NotificationPrefs prefs);      // set(toMap + updatedAt serverTimestamp)
}
// providers (notification_providers.dart)
final notificationRepositoryProvider = Provider<NotificationRepository>(…);
final notificationPrefsRepositoryProvider = Provider<NotificationPrefsRepository>(…);
final unreadCountProvider = StreamProvider<int>(…);            // 0 when signed out
final latestNotificationProvider = FutureProvider.autoDispose<AppNotification?>(…);   // re-runs when unreadCountProvider changes (Decision 12)
final notificationPrefsProvider = StreamProvider.autoDispose<PrefsSnapshot>(…);

// lib/data/push/
@immutable class PushOpen { const PushOpen({required this.target, this.notificationId}); }
abstract class PushMessaging { Future<String?> token(); Stream<String> get tokenRefresh; Stream<PushOpen> get opened; Future<PushOpen?> initialOpen(); }
enum NotificationPermissionStatus { granted, denied, permanentlyDenied, notDetermined }
abstract class NotificationPermissionPort {
  Future<NotificationPermissionStatus> status(); Future<NotificationPermissionStatus> request(); Future<void> openSettings();
}
abstract class DeviceRegistry { Future<void> register({required String uid, required String token}); Future<void> unregister(String uid); }
class PrefsPrimerStore implements PrimerStore { PrefsPrimerStore(SharedPreferences prefs); }   // key 'notifPrimerLaterAt'
final pushMessagingProvider, notificationPermissionProvider, deviceRegistryProvider, primerPolicyProvider;
/// Watched by _Root: registers the token while signed in AND permission granted; re-registers on refresh.
final pushRegistrationProvider = Provider<PushRegistration>(…);   // .refresh() after a grant; .signOut() = unregister then AuthRepository.signOut

// lib/data/badges/badge.dart
enum BadgeSource { review, system }
@immutable class BadgeDefinition { id, name, shortName?, description, icon, source, audience, order, hiddenWhenLocked, hasProgress }
@immutable class EarnedBadge { badgeId, awardedAt, snapshotText? }
@immutable class BadgeProgressEntry { current, target }
abstract class BadgeRepository {
  Future<List<BadgeDefinition>> catalog();                       // badges/*, ordered; cached by the provider
  Stream<List<EarnedBadge>> watchEarned(String uid);
  Stream<Map<String, BadgeProgressEntry>> watchProgress(String uid);   // owner only
}
class BadgesSeenStore { BadgesSeenStore(SharedPreferences p); DateTime? seenAt(String uid); Future<void> markSeen(String uid, DateTime at); }
final badgeRepositoryProvider, badgeCatalogProvider /* FutureProvider, keepAlive */, earnedBadgesProvider /* family uid */,
      myBadgeProgressProvider, badgesSeenStoreProvider;
final badgeChipsProvider = Provider.autoDispose.family<AsyncValue<List<BadgeView>>, String>(…);   // earned by order, label shortName ?? name

// core changes
enum NotificationTone { neutral, success, action, danger, muted }
NotificationRowData({required id, required IconData icon, NotificationTone tone = NotificationTone.neutral, required title, required body,
  required timeLabel, required unread, thumbUrl, groupAvatars});            // replaces `kind`; NotificationKind and notificationKindIcon removed
NotificationRow({required item, required onTap, required onMarkRead, VoidCallback? onMuteKind});   // null hides the menu item and custom action
PermissionPrimer({required title, required List<PrimerBenefit> benefits, String? note, required onEnable, required onLater, bool enabling = false});
@immutable class PrimerBenefit { const PrimerBenefit(this.icon, this.text); }
TabBadge({required count, required child, String? semanticsValue});          // default stays tabBadgeCount(n)
// lib/core/feature_flags.dart
const kJobsEnabled = false; const kInstantEnabled = false;
```

Tone colours: neutral = `primarySubtle` disc + `primary` glyph (the mock's default `.nic`), success = `successSubtle`/`success`, action = `warningSubtle`/`warning` (dark ink on light), danger = `errorSubtle`/`error`, muted = `surfaceMuted`/`foregroundMuted`; dark variants from `AppColorsDark`. `PermissionPrimer` shows each benefit as icon + text rows, the note under the buttons, and `enabling` puts the primary button in its loading state. `pushRegistrationProvider` never calls `token()` unless `status() == granted`.

- [ ] **Step 1: Contract check** (app part).
- [ ] **Step 2: Write the failing tests:** data: "a notification doc parses with actors, count and readAt null as unread"; "unknown tab code reads as system"; "first page listens with tab filter and limit 30, next cursor only on a full page"; "older page starts after the cursor"; "markRead writes one batch with readAt only"; "unread count reads 0 when the field is missing"; "targetExists is false for a missing booking"; "prefs fromMap fills defaults and forces booking inApp"; "withChannel cannot turn booking inApp off"; "toMap round-trips"; "a badge doc parses; missing shortName is null"; "progress doc entries parse"; "badgeChips orders by catalogue order and uses shortName"; push: "no token registration while not granted"; "granted registers the token and re-registers on refresh"; "signOut unregisters before signing out and still signs out when unregister fails"; "primer store remembers later()"; core: "row shows the given icon and tone disc"; "null onMuteKind hides the menu item and the custom action"; "primer lists three benefits, the note and one primary button"; "enabling shows the button loading"; "TabBadge uses the given semantics value"; "badgeIconOf maps the catalogue icon keys, unknown → medal".
- [ ] **Step 3: Run** `flutter test test/data test/core` → fail. **Step 4: Implement** (+ exports, gallery tiles; remove the `NotificationBell` tile). **Step 5: Run** `flutter analyze && flutter test test/data test/core` → pass.
- [ ] **Step 6: Commit** `feat(data): notifications, prefs, push ports and badges; core row tones and primer benefits [10a]`.

### Task 5: S17.01 inbox, S09.01 row, Hồ sơ tab badge, deep links

**Files:**
- Create: `lib/features/notifications/notifications_screen.dart`, `notifications_controller.dart`, `notification_visuals.dart`, `notification_targets.dart`, `push_open_handler.dart`, `notifications_analytics.dart`; `test/support/notifications_world.dart`
- Modify: `lib/app/router.dart` (`/notifications`), `lib/main.dart` (`_Root` watches `pushOpenHandlerProvider` and `pushRegistrationProvider`), `features/shell/tab_badges.dart` (`AppTab.profile: unread`), `tab_shell.dart` (profile tab `semanticsValue: l.notificationUnreadCount(n)`), `features/shell/placeholder_tabs.dart` (S09.01 "Thông báo" row under name/role), `lib/l10n/app_vi.arb`
- Test: `test/features/notifications/notifications_screen_test.dart`, `notifications_controller_test.dart`, `notification_targets_test.dart`, `push_open_handler_test.dart`, `test/features/shell/profile_notifications_row_test.dart`, `tab_badges_test.dart` (extend)

**Interfaces:**
- Consumes: `NotificationRepository`, `unreadCountProvider`, `latestNotificationProvider`, `NotificationPrefsRepository` (mute), `PushMessaging.opened/initialOpen`, `currentProfileProvider`, `NotificationRow`, `SegmentedTabs`, `SectionHeader`, `AsyncView`, `EmptyState`, `ErrorState`, `OfflineBanner`.
- Produces:

```dart
({IconData icon, NotificationTone tone}) notificationVisualOf(String type, {String? variant});   // §3h.2 sprite → AppIcons; unknown → info/neutral
String notificationTimeLabel(DateTime createdAt, DateTime now, AppLocalizations l);   // Vừa xong · {n} phút · {n} giờ · Hôm qua · {n} ngày (≤ 30) · d/M
enum NotificationSection { today, week, earlier }
NotificationSection sectionOf(DateTime createdAt, DateTime now);                      // Vietnam calendar day; week = within 7 days
/// Null when the target is not allowlisted (Decision 3).
String? safeTarget(String raw);
class NotificationsState { final List<AppNotification> items; final NotificationCursor? next; final bool loadingMore, fromCache; }
final notificationTabFilterProvider = StateProvider.autoDispose<NotificationTab?>((_) => null);
final notificationsControllerProvider = AsyncNotifierProvider.autoDispose<NotificationsController, NotificationsState>(…);
class NotificationsController { Future<void> loadMore(); void markRead(String id); Future<void> markAllRead(); Future<MuteUndo?> mute(AppNotification n); Future<void> refresh(); }
final pushOpenHandlerProvider = Provider<void>(…);   // waits for a signed-in profile, then markRead(id) + router.push(safeTarget)
```

Behaviour (mock `#S17.01`): `ScreenCode(ScreenCodes.notifications)`; bar Back · "Thông báo" · gear (→ `/settings/notifications`, tooltip "Cài đặt thông báo"); `SegmentedTabs` Tất cả · Đặt lịch|Công việc (by current role) · Sự kiện · Hệ thống; meta row "{n} chưa đọc" + text button "Đánh dấu tất cả đã đọc" (hidden at 0, disabled when `fromCache`); sections Hôm nay / 7 ngày qua / Trước đó with `SectionHeader`; rows `NotificationRow` (grouped rows: `groupAvatars` from `actors`). Loading: 6 `NotificationRow.skeleton()`; empty: bell icon + "Chưa có thông báo nào" + body + one action ("Khám phá nhiếp ảnh gia" → `/action` for customers, "Mở Công việc" → `/bookings` for photographers); filtered empty: "Chưa có thông báo nào trong mục {tab}"; error `ErrorState` + "Thử lại"; `fromCache` → `OfflineBanner`. Pull to refresh re-subscribes. Infinite scroll loads 30 more near the end.

Controller rules (easy to get wrong): the live first page replaces only the first `limit` rows; older pages are appended and de-duplicated by id; pending read ids are applied optimistically (`markedRead`) and flushed by a 1 s debounce `Timer` and in `ref.onDispose`; a tap = `markRead` + navigate; navigation: `safeTarget == null` → SnackBar "Nội dung này không còn"; `/b/` and `/chat/` targets call `targetExists` first; mute (long press): category `booking` → no action (Decision 7); otherwise save prefs with push and inApp off, SnackBar "Đã tắt loại thông báo này" + "Hoàn tác" restoring the previous prefs.

S09.01 row (mock `#S09.01`, `portfolio-awards.md`): `GlassCard(highlight: false)` row, bell in a light disc, "Thông báo", newest title one line (`latestNotificationProvider`; empty → "Chưa có thông báo nào"), unread count bubble (hidden at 0), chevron; one merged semantics "Thông báo, {n} thông báo chưa đọc, {title}"; tap → `/notifications`. Key `Key('open-notifications')`.

- [ ] **Step 1: Write the failing tests:** "groups rows into Hôm nay, 7 ngày qua and Trước đó in Vietnam time"; "time labels: 5 phút, 1 giờ, Hôm qua, 12 ngày"; "photographers see Công việc, customers Đặt lịch"; "switching tab re-queries with that tab"; "one listener while open, none after pop"; "tap marks read optimistically and opens the target"; "three taps in a second write one batch"; "leaving flushes pending marks"; "mark all calls the callable and dims every row"; "mark all is disabled offline and the offline banner shows"; "unknown target is not opened"; "gone booking shows the snack bar"; "long press mute saves prefs and undo restores them"; "booking rows have no mute action"; "grouped row shows at most 3 avatars"; "loading shows row skeletons"; "empty state action differs by role"; "load more appends the next page without duplicates"; "Hồ sơ tab shows 9+ for 12 unread and reads '12 thông báo chưa đọc'"; "S09.01 row shows the newest title and opens /notifications"; "S09.01 row re-fetches when the count changes, never listens"; "push open marks read and navigates after sign-in"; "initial push open is handled once"; "320 dp and 1.3× text: titles wrap, body stays 2 lines" (light and dark).
- [ ] **Step 2: Run** → fail. **Step 3: Implement.** **Step 4: Run** `flutter analyze && flutter test test/features/notifications test/features/shell` → pass.
- [ ] **Step 5: Commit** `feat(notifications): S17.01 inbox, Hồ sơ unread badge, S09.01 row, push deep links [10a]`.

### Task 6: S17.02 settings, S17.03 primer and its moments

**Files:**
- Create: `lib/features/notifications/notification_settings_screen.dart`, `notification_settings_controller.dart`, `notification_primer.dart`
- Modify: `lib/app/router.dart` (`/settings/notifications` as a child of `/settings`), `features/settings/settings_screen.dart` (group "Thông báo" with one row → S17.02, between "Kiểu nút chính" and "Đăng xuất"; `_confirmSignOut` and `ProfileTab` sign-out use `pushRegistrationProvider.signOut()`), `features/booking/booking_detail_screen.dart` (after the paid toast when `justPaid`, call `maybeAskForNotifications(customerBooking(name))`; after a successful accept, `photographer`), `features/work/work_screen.dart` (`_accept`: ask before navigating), `lib/l10n/app_vi.arb`
- Test: `test/features/notifications/notification_settings_screen_test.dart`, `notification_primer_test.dart`, `test/features/settings/settings_test.dart` (extend), `test/features/booking/booking_detail_primer_test.dart`, `test/features/work/work_accept_primer_test.dart`

**Interfaces:**
- Produces:

```dart
sealed class PrimerContext { const PrimerContext(); }
class CustomerBookingPrimer extends PrimerContext { const CustomerBookingPrimer(this.photographerName); }   // s65_titleCustomerBooking
class CustomerInstantPrimer extends PrimerContext { const CustomerInstantPrimer(); }                       // for the instant plans
class PhotographerPrimer extends PrimerContext { const PhotographerPrimer(); }                             // s65_titlePhotographer
/// Shows S17.03 when allowed; resolves after the sheet closes. Never throws.
Future<void> maybeAskForNotifications(BuildContext context, WidgetRef ref, PrimerContext c);
class NotificationSettingsController extends AutoDisposeAsyncNotifier<NotificationSettingsState> {
  Future<void> setChannel(NotificationCategory c, {bool? push, bool? inApp});
  Future<void> setQuietEnabled(bool v); Future<void> setQuietRange(String from, String to);
  Future<void> setReminder({bool? h24, bool? h2}); Future<void> openOsSettings(); Future<void> requestPermission();
}
class NotificationSettingsState { final NotificationPrefs prefs; final bool fromCache; final NotificationPermissionStatus os; }
```

S17.02 (mock `#S17.02`, `ScreenCode(ScreenCodes.notificationSettings)`): bar Back · "Thông báo"; banner card when `os != granted`: warning bell, "Thông báo đang tắt trên máy", "Bạn sẽ không nhận push cho tới khi bật lại.", outline xs button "Mở Cài đặt" (`permanentlyDenied` → `openSettings()`; `denied`/`notDetermined` → `request()`, label "Bật thông báo"); OS state re-read on `AppLifecycleListener.onResume`. Table card: header "Loại · Push · Trong app"; rows Đặt lịch và thanh toán, (Việc đăng tuyển if `kJobsEnabled`), (Chụp ngay if `kInstantEnabled`; customers only Push), Sự kiện, Tin nhắn, Huy hiệu và đánh giá, Khuyến mãi; each switch `Semantics` "{nhóm}, {Push|Trong app}, {bật|tắt}"; booking Trong app disabled-on "…, luôn bật"; while OS is off the Push column shows the caption "Đang tắt trên máy". Card: "Giờ yên lặng" + "{from}–{to} · chỉ thông báo quan trọng vẫn có âm" + switch; tapping the range opens two `showTimePicker`s (from, then to); "Nhắc buổi chụp" + filter chips "24 giờ", "2 giờ". Writes are optimistic; error → SnackBar "Không lưu được, thử lại" and the old value back; `fromCache` → switches disabled + `OfflineBanner`. Loading = skeleton rows. No primary button on this screen.

S17.03 (mock `#S17.03`): `showAppSheet` (dismiss by drag/tap outside/back = "Để sau"), content `PermissionPrimer` in `ScreenCode(ScreenCodes.notificationPermission)`, title per context, three benefits (Global Constraints), note, "Bật thông báo" → `enabling` while the OS dialog is up → `granted`: close, SnackBar "Đã bật thông báo", `pushRegistration.refresh()`; denied: close silently. Guard: `status()` granted or permanentlyDenied → return; `PermissionPrimerPolicy.shouldAsk(atAppStart: false)` false → return; a static in-flight flag keeps one sheet at a time; `maybeAsk…` waits for any route sheet in progress to finish (call sites invoke it after their own sheet/toast).

- [ ] **Step 1: Write the failing tests:** settings: "defaults show every switch on except Khuyến mãi"; "jobs and instant rows are hidden while their flags are off"; "booking Trong app is on, disabled and reads 'luôn bật'"; "a switch saves optimistically"; "a failed save shows 'Không lưu được, thử lại' and restores the switch"; "offline disables switches and shows the banner"; "OS off shows the banner; permanently denied opens settings"; "the banner disappears after granting and resuming"; "quiet range picks from then to"; "reminder chips toggle h24 and h2"; "switch semantics read 'Sự kiện, Push, bật'"; primer: "never asked when already granted"; "never asked when permanently denied"; "not asked within 7 days of Để sau"; "Để sau and dismiss both snooze"; "enable shows loading, then 'Đã bật thông báo' and registers the token"; "denied closes without a message"; "only one sheet at a time"; call sites: "S05.02 with paid=1 asks with the photographer's name after the toast"; "S05.02 without paid=1 never asks"; "accept on S06.01 asks before opening the chat"; S09.02: "Thông báo row opens /settings/notifications"; "sign-out unregisters the device first".
- [ ] **Step 2: Run** → fail. **Step 3: Implement.** **Step 4: Run** `flutter analyze && flutter test test/features` → pass.
- [ ] **Step 5: Commit** `feat(notifications): S17.02 settings and S17.03 primer after booking and accept [10a]`.

### Task 7: S03.02 badges, badge rows on S03.01/S09.01, docs in step

**Files:**
- Create: `lib/features/badges/badges_screen.dart`, `badges_view.dart` (pure view model: sections, counts, nearest, isNew), `test/support/badges_world.dart`
- Modify: `lib/app/router.dart` (`/u/:uid/badges`, declared before `/u/:uid`), `features/photographer_profile/widgets/profile_header.dart` (BadgeRow after the bio), `features/shell/placeholder_tabs.dart` (BadgeRow under the Thông báo row), `lib/l10n/app_vi.arb`
- Docs: main spec §3h.2 (row `booking_cancelled`), §3h.1/S17.01 filter sentence (Decision 1), §2 code table status cells S03.02/S17.01–S17.03 → "Đã có"; `screens/account.md` (S17.02 hidden rows, Decision 8; S17.01 targets, Decision 3; S03.02 nearest-badge card, Decision 17); `components/shared-components.md` (NotificationRow icon/tone and nullable mute, NotificationBell removed, PermissionPrimer benefits, TabBadge `semanticsValue`); `data-model/domain-model.md` (`NotificationType` = the domain list, `Notification` fields, `NotificationPrefs`, `Device` doc id), `relational-schema.md` (Decision 21 columns, `notification_prefs`, mapping `users/{uid}/notifications/{id}`); gallery regenerated
- Test: `test/features/badges/badges_screen_test.dart`, `badges_view_test.dart`, `test/features/photographer_profile/profile_badges_test.dart`, `test/features/shell/profile_badges_row_test.dart`

**Interfaces:**
- Consumes: `badgeCatalogProvider`, `earnedBadgesProvider(uid)`, `myBadgeProgressProvider`, `badgesSeenStoreProvider`, `badgeChipsProvider(uid)`, `currentProfileProvider`, `BadgeTile`, `BadgeRow`, `CapacityBar`, `showAppSheet`.
- Produces:

```dart
@immutable class BadgesView {
  final List<BadgeTileVm> fromReviews, fromSystem; final int earned, shown; final int reviewsEarned, reviewsShown, systemEarned, systemShown;
  final BadgeTileVm? nearest;           // own view with nothing earned only
}
@immutable class BadgeTileVm { final BadgeView badge; final BadgeProgress? progress; final bool isNew; final DateTime? awardedAt; final String description; }
BadgesView buildBadgesView({required List<BadgeDefinition> catalog, required List<EarnedBadge> earned,
  Map<String, BadgeProgressEntry>? progress /* null for others */, required bool own, required bool photographer, DateTime? seenAt});
class BadgesScreen extends ConsumerStatefulWidget { const BadgesScreen({super.key, required this.uid}); }
```

Layout (mock `#S03.02`, `ScreenCode(ScreenCodes.badges)`): bar Back · "Huy hiệu" · meta "{earned} / {shown}" (own only); section header "Từ đánh giá" + "{e} / {s}"; 2-column grid of `BadgeTile`; "Từ hệ thống" likewise; a section with no tiles is omitted. Earned tile condition = snapshot text; locked = description, grey disc, progress when present. Loading: 4 `BadgeTile.skeleton()` per section; error `ErrorState`. After the first frame with data on the own view: `badgesSeenStore.markSeen(uid, now)`. Tile tap → sheet: name, description, "Đạt ngày {d/M/yyyy}" or "{cur} / {target}". Analytics hook `badges_open{own}`, `badge_detail{badgeId}`.

- [ ] **Step 1: Write the failing tests:** view: "own photographer sees 12 minus hidden new_member"; "customers see customer and both badges only"; "others see earned only, no progress, no counts"; "earned first by order within each section"; "isNew only for awards after seenAt and only on the own view"; "nearest picks the highest current/target when nothing is earned"; screen: "header reads '5 / 12' and sections '2 / 3', '3 / 9' with the mock data"; "locked tile shows 3 / 5"; "the Mới dot shows now and is gone on the next visit"; "others with no badges see 'Chưa có huy hiệu nào'"; "tile tap shows the earned date"; "no Verified tick on this screen"; "skeleton while loading"; "320 dp and 1.3× without overflow" (light, dark); profile rows: "S03.01 shows up to 3 earned chips after the bio and Tất cả opens /u/:uid/badges"; "S03.01 hides the row when nothing is earned"; "S09.01 shows chips and Tất cả even with none earned".
- [ ] **Step 2: Run** → fail. **Step 3: Implement**, then the docs and gallery (`python3 scripts/tools/build_ui_components.py` from the repo root). **Step 4: Run** the whole suite `flutter analyze && flutter test`, `(cd packages/domain && npm test)`, `(cd app_flutter/firebase/functions && npm test && npm run build)` → pass.
- [ ] **Step 5: Commit** `feat(badges): S03.02 badges screen, badge rows on S03.01 and S09.01; docs in step [10a]`.

---

## Needs the owner

1. **`unreadCount` on the public `users/{uid}` doc** (spec §3h.3) lets any signed-in user read another user's unread count. Plan follows the spec; moving it to `users/{uid}/private/notification_state` is a one-line rules/adapter change if the owner prefers.
2. **Retention:** no pruning of old inbox rows in v1 (Decision 21). Suggest deleting read rows older than 90 days in the nightly job.
3. **Jobs and Chụp ngay rows hidden on S17.02** until those features ship (Decision 8), unlike the mock.
4. **Server-rendered Vietnamese copy** (Decision 2): the per-type titles/bodies are written in this plan (mock rows verbatim where they exist); the owner may want to review the wording of the rows the mock does not show.
