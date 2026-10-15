# Seed data (local emulators only)

`scripts/backend-local.sh` loads this seed on the first start (or with `--fresh` / `--seed`).
Source: `fixtures.ts`. **Test values only**: these accounts and numbers exist only in the
local Auth and Firestore emulators; the seed refuses to run unless `FIRESTORE_EMULATOR_HOST`
and `FIREBASE_AUTH_EMULATOR_HOST` point at a local host.

Password for every account: `seed-password-1`

| Account (email) | uid | Role | Notes |
|---|---|---|---|
| `lan.customer@seed.test` | `seed-customer-lan` | customer | private phone `+84903000001` (Zalo allowed) |
| `minh.nophone@seed.test` | `seed-customer-minh` | customer | no phone: server answers `phone_required` |
| `an.verified@seed.test` | `seed-photographer-an` | photographer | verified, Hà Nội; Gọi + Zalo + WhatsApp; `+84912000001`, Zalo `+84912000002`, WhatsApp `+14155550101` |
| `binh.unverified@seed.test` | `seed-photographer-binh` | photographer | not verified, Đà Nẵng; Gọi only; `+84987000001`; shows the S03.01 "Chưa nhận đơn" variant and cannot be booked (`acceptingOrders: false`) |
| `cuc.studio@seed.test` | `seed-photographer-cuc` | photographer | studio (`providerType: studio`), TP.HCM; private studio address, public district Quận 1; Gọi only; `+84938000001` |
| `dung.artist@seed.test` | `seed-photographer-dung` | photographer | artist (NAG tier, `providerType: artist`, `approvedAwardCount: 3`), Huế; Gọi only; `+84905000001` |
| `admin.staff@seed.test` | `seed-staff-admin` | staff | custom claim `staffRole: 'admin'`: may call `reviewAward` and is the `--actor` of `npm run awards` |

| Booking | Customer ↔ photographer | Status | `getContactLink` |
|---|---|---|---|
| `seed-booking-accepted` | Lan ↔ An | accepted | unlocked (all three channels) |
| `seed-booking-upcoming` | Lan ↔ An | upcoming | unlocked |
| `seed-booking-requested-binh` | Lan ↔ Bình | requested | `call` only; `zalo`/`whatsapp` → `not_found` |
| `seed-booking-cancelled` | Lan ↔ An | cancelled | `contact_locked` |
| `seed-booking-completed-recent` | Lan ↔ An | completed 3 days before seeding | unlocked |
| `seed-booking-completed-old` | Lan ↔ An | completed 40 days before seeding | `contact_locked` |

| Post / album | Owner | Notes |
|---|---|---|
| `seed-post-an-1`, `-2` | An | `work` posts in album `seed-album-an-family` ("Gia đình", position 1; 5 photos) |
| `seed-post-an-3` | An | `work` post in album `seed-album-an-street` ("Đường phố", position 2; 1 photo) |
| `seed-post-an-4`, `-5` | An | `work` posts on the timeline only (no album) |

| Award | Owner | Status |
|---|---|---|
| `seed-award-dung-1`, `-2`, `-3` | Dũng | approved (gold, silver, bronze; make Dũng an artist) |
| `seed-award-binh-1` | Bình | pending (in the review queue: `npm run awards -- list`) |

Booking payments are paid by bank QR (`method: bank_qr`, `transferCode` "PB" + 6 characters
derived from the payment id). The fake payment webhook (`paymentWebhook?provider=fake`, and
`confirmFakePayment`, which signs and runs it in-process) checks its `x-pb-signature` with
`FAKE_PAYMENT_WEBHOOK_SECRET` from `.env.local` (emulator) and `.env.booking-c1922` (dev project):
a self-made test value; the real secret comes with the payment intermediary unit.

## Reviews (tomato/brick)

| Photographer | Card / profile | `stats` | Seeded `reviews/*` |
|---|---|---|---|
| An | 97% from 58 reviews (keeps `top_rated`: "97% cà chua từ 58 đánh giá") | 56 tomato, 2 brick, `signedSum` 54.62, `score` 0.942, `punctualMentions` 3 | `seed-review-an-1` tomato ×10, `-2` brick ×3 (Đến trễ, Giao ảnh chậm), `-3` tomato ×6 (the newest three of the 58; texts of the mock) |
| Cúc | "Mới · 3 đánh giá" (under 5, no %) | 3 tomato, folded with `addVerdict` | `seed-review-cuc-1..3`, all tomato |
| Dũng | 50%, with bricks | 3 tomato, 3 brick, folded with `addVerdict` | `seed-review-dung-1..6`; every brick has its reasons |
| Bình | nothing shown (0 reviews) | none | none |

Reviews sit on synthetic booking ids (no booking docs), customers Lan and Minh, and are seeded already
counted (`countedAt` set), so `onReviewWrite` neither recounts them nor sends a notice.
`seed-booking-completed-recent` stays unreviewed: sign in as Lan to try S05.05.

Run `scripts/backend-local.sh --fresh` once: star reviews in saved emulator data are not converted.

## Earnings and payouts (plan 10b)

| Data | Owner | Notes |
|---|---|---|
| `payoutAccounts/{uid}` + `accounts/seed-account-an-1` | An | VCB, `0123456789` (stored encrypted with the emulator key in `.secret.local`; the owner view shows `•••• 6789`), holder `NGUYEN VAN AN`; `nameStatus: matched`, active from the seed start (`SEED_CREATED_AT`) |
| `users/{uid}/private/identity` | An | identity legalName (An): `Nguyễn Văn An`, `method`/`provider` `fake` (test value; the doc's full shape is #135's) |
| Payout `seed-payout-an-1` | An | `paid`, the first payout to the account (approved by `seed-staff-admin`); 1 500 000 gross, tax 7% 105 000, net 1 395 000; its payment (`seed-payment-seed-booking-completed-old`) is `paid_out`, with `payout_paid` −1 395 000 and `tax_withheld` −105 000 ledger entries |
| `seed-booking-disputed` | Lan ↔ An | completed 10 hours before seeding; payment `disputed`, reason "Ảnh giao thiếu so với gói" |
| `earnings/{uid}` + `items/*` | An, Bình | the projection, computed with the same pure functions as the triggers (An: held 3 × 1 500 000, soon 1 500 000, received 1 500 000; the paid row carries its tax and net) |
| Payout account | Bình | none (the S06.05 add-account card) |

## Chats (S07)

Three 1-1 conversations, built by `directChatDocuments` in `fixtures.ts` (chat fields folded from the messages with the domain's `afterMessage`; `bookingStatus` is read from the seeded booking, not typed in):

| Chat (`chats/{customer}_{photographer}`) | Kind | Messages | What it shows on S07.02 |
|---|---|---|---|
| `seed-customer-lan_seed-photographer-an` | `booking` (`seed-booking-upcoming`, `bookingStatus` = its status) | 3 text, the last from An | "Sắp tới" badge; Lan has 2 unread (matches her grouped inbox row) |
| `seed-customer-lan_seed-photographer-cuc` | `inquiry`, `lastMessageAt` = seed time − 20 days | 2 text (Lan, Cúc) | preview "đã đóng"; Lan's next message reopens it unless Cúc turns inquiries off |
| `seed-customer-minh_seed-photographer-dung` | `inquiry`, open | 1 text from Minh | Dũng has 1 unread (as Dũng: unread 1) |

Each chat has `members/{uid}` docs with `unreadCount` for both sides (0 where nothing is unread).

Each member who received a message also has the grouped inbox row `g_chat_{chatId}` that `onChatMessageCreated` would have left (same last and recent message ids; unread with the member's unread count, read otherwise). The seed writes the messages with the Admin SDK, so that trigger still runs for each one after seeding; with the rows in place every run is a duplicate and writes nothing.

## Notifications and badges

| Data | Owner | Notes |
|---|---|---|
| Inbox rows (`users/{uid}/notifications/*`) | Lan | 6 rows: booking accepted (unread), 24 h reminder (read), refund (read), declined (read, 12 days old), grouped chat with An, 2 messages (unread), chat with Cúc (read, 20 days old) |
| Inbox rows | An | booking request (unread), a sample `review_tomato` notice "Bạn nhận 🍅 ×7 từ buổi chụp CN 27/9" (read), chat with Lan (read) |
| Inbox rows | Cúc, Dũng | chat with Lan (read); chat with Minh (unread) |
| `users/{uid}/private/inbox` | Lan, An, Cúc, Dũng | `unreadCount` 2, 1, 0 and 1, matching the unread rows |
| Earned badges | An | `top_rated`, `shoots_10`, `complete_profile`; progress `punctual` 3/5, `shoots_50` 12/50 |
| Earned badges | Lan | `loyal_customer`; progress `sharer` 0/5, `detailed_reviewer` 3/5 |
| `badges/{id}` | all | the 12-badge catalogue |
| `users/{uid}/private/notification_prefs` | none | no doc, so the defaults apply |

Push goes through the Functions emulator's `LoggingPushSender` (type and channel logged, nothing sent).

Try a call while the emulators run (from `app_flutter/firebase/functions`, with the project id
`scripts/backend-local.sh` printed). The script refuses to run unless the three emulator hosts
point at a local host, so export them first:

```bash
export FIRESTORE_EMULATOR_HOST=127.0.0.1:8080 FIREBASE_AUTH_EMULATOR_HOST=127.0.0.1:9099 \
  FUNCTIONS_EMULATOR_HOST=127.0.0.1:5001 GCLOUD_PROJECT=<project>
npm run try:contact -- lan.customer@seed.test seed-booking-accepted zalo
# 200 {"result":{"url":"https://zalo.me/84912000002"}}
```

## Staff CLI for awards

`tools/awards.ts` is the staff review of award proofs until the web dashboard (S23.07, #83) exists:
`list` (pending awards, oldest first, with how long each has waited), `show <awardId>` (the award,
its proof links and files) and the decisions `approve`, `needs-info`, `reject`, `revoke`. A decision
calls the same `reviewAward` use case as the callable, so the same rules, notification and tier
recompute (`onAwardWrite`) apply; `--actor` must be a user with the admin claim.
`npm run awards -- --help` lists the commands. `list` shows calendar time waiting, while S25.02
promises a review in 3 business days: count weekends and holidays by eye.

### Local (emulators running via `scripts/backend-local.sh`)

`scripts/awards-local.sh` points the CLI at the local emulators (Firestore, Auth and Storage on
127.0.0.1), unsets `GOOGLE_APPLICATION_CREDENTIALS` and refuses a half-set or non-local emulator
environment. `show` downloads the proof files to `$TMPDIR/awards/<awardId>/` (named
`<index>-<file name>`) and prints the paths; links are printed as they are.

```bash
scripts/awards-local.sh list
scripts/awards-local.sh show seed-award-binh-1
scripts/awards-local.sh approve seed-award-binh-1 --actor seed-staff-admin
scripts/awards-local.sh needs-info <awardId> "Thiếu ảnh giấy chứng nhận" --actor seed-staff-admin
```

Check: sign in as `binh.unverified@seed.test`, open Cài đặt → Giải thưởng: the award reads
"Đã duyệt"; a notification `award_reviewed` is in Bình's inbox; the tier card says "Còn 2 giải đã
duyệt nữa để nhận tích vàng". An award created in the app (with proof photos) shows its files with
`show`; the seeded one has a link only.

### Real project

Run the CLI directly, with `GOOGLE_APPLICATION_CREDENTIALS` (a service account key) and
`STORAGE_BUCKET` (or `FIREBASE_STORAGE_BUCKET`), and no emulator host set:
`npm run awards -- list`. `show` prints signed URLs that expire in 15 minutes, so the credentials
must be able to sign. `--actor` is the uid of a user with the admin claim. The dev project
`booking-c1922` is on Spark, so reviews there are not run; this is for the production project.

## Staff CLI for payouts

`npm run payouts -- --help` lists the commands: `due` (payees with released money and open
payouts, `needs_approval` included), `show <payoutId>` (the account is printed masked, `•••• 6789`), and
`create <payeeId>`, `approve <payoutId>`, `execute <payoutId>`, `hold <payoutId> "<reason>"`,
`resume <payoutId>`, `run-daily`, each with `--actor <uid>` of an admin (`seed-staff-admin` locally). Against the emulators set
`FIRESTORE_EMULATOR_HOST` and `FIREBASE_AUTH_EMULATOR_HOST`; the key comes from `.secret.local`.
Against a real project set `GOOGLE_APPLICATION_CREDENTIALS` and `PAYOUT_ACCOUNT_KEY`. `execute`
and `run-daily` work only with the fake gateway (emulators or `PAYOUTS_MODE=fake`): no real bank
adapter exists.

Daily payouts on the emulator: `npm run payouts -- run-daily --actor seed-staff-admin` does what the
daily `createPayouts` job (10:00 Vietnam time) does and prints its report; approve a first payout
with `npm run payouts -- approve <id> --actor seed-staff-admin`, then run it again to send it.

```bash
npm run payouts -- due
npm run payouts -- create seed-photographer-an --actor seed-staff-admin   # batches An's released payment (completed-recent)
npm run payouts -- run-daily --actor seed-staff-admin
npm run payouts -- approve <payoutId> --actor seed-staff-admin
```

## Photo events (plan 10c)

| Data | Owner | Notes |
|---|---|---|
| `seed-event-an-free-photowalk` | An | open, free ("Không thu phí"), starts in 8 days, capacity 20, 1 seat taken; group chat `event_seed-event-an-free-photowalk` (An, Lan) |
| `seed-event-an-paid-workshop` | An | open, 250 000 VND per ticket, starts in 15 days, capacity 12. Registering holds the seats for 10 minutes and opens a payment; on the emulator and the dev project the fake gateway pays it ("Thanh toán" in the S11.03 sheet, `confirmFakeTicketPayment`), elsewhere the fake-payment gate refuses until #129 brings the real gateway |
| `seed-registration-lan-free-walk` | Lan | free registration to the walk: `paid`, `contactEligible: false`, ticket `VE-LANA-0000`, no `private/contact` snapshot (the host never gets Lan's phone) |
| Timeline of the walk | Lan, Minh | `seed-post-lan-share` (`event_share`, visible) and `seed-post-minh-share` (pending: Minh holds no ticket, so it shows only in the managers' "Chờ duyệt" tab); `postCount` 1 |
| Group chat of the walk | An, Lan | member docs (names only), a join line for Lan, An's announcement `seed-msg-announcement` pinned |
| `seed-event-an-night-walk` | An | "Chụp phố đêm", open, free, starts **36 hours after seeding** (meeting point Nhà hát Thành phố), `soonNoticeAt` null: the next event clock run sends the S17 `event_soon` reminder; group chat with An and Lan |
| `seed-registration-lan-night-walk` | Lan | free registration to the night walk: `paid`, ticket `VE-LANB-0000` |

Each event also has its hashtag guard (`event_hashtags/*`), the booked day in An's availability
(unless a seed booking already holds that day), and each registration its `ticket_codes/*` entry.

## Follows and saved items (S19)

| Follow | Follower | Followee | Notes |
|---|---|---|---|
| Lan → An | Lan (`seed-customer-lan`) | An (`seed-photographer-an`) | An's `followerCount`: 2 |
| Minh → An | Minh (`seed-customer-minh`) | An (`seed-photographer-an`) | |
| Lan → Dũng | Lan (`seed-customer-lan`) | Dũng (`seed-photographer-dung`) | Dũng's `followerCount`: 1 |

| Saved item | User | Target | Notes |
|---|---|---|---|
| Saved post | Lan | `seed-post-an-1`, `seed-post-an-2` | in `saves/{userId}_{postId}` |
| Saved photographer | Lan | Cúc (`seed-photographer-cuc`) | in `savedPhotographers/{userId}_{photographerId}` |

## Discovery stats (S02)

| Photographer | `startingPrice` | `stats.nextFreeDate` | `stats.completedCount` | Notes |
|---|---|---|---|---|
| An | 1 500 000 ₫ | computed from today & booked days | 3 | completed bookings: `recent`, `old`, `disputed` |
| Bình | 1 200 000 ₫ | computed from today | 0 | unverified, `acceptingOrders: false` |
| Cúc | `null` | computed from today | 0 | no services seeded |
| Dũng | `null` | computed from today | 0 | no services seeded |

| Item | Key / Path | Value | Notes |
|---|---|---|---|
| Post likes | `posts/seed-post-an-1` | `likeCount: 2` | Lan, Minh in `likes/{userId}_{postId}` |
| Post saves | `posts/seed-post-an-1` | `saveCount: 1` | Lan in `saves/{userId}_{postId}` |
| Explore catalog | `catalog/explore` | `portrait: 1`, `family: 1` | active services with category count |

To recompute all discovery stats across the emulator database:
```bash
npm run stats -- recompute
```

## Running a clock on the emulators

The emulators never fire scheduled functions. `npm run clock -- events` runs the event clock once
(close, complete, refunds, then the 48-hour `event_soon` reminders) and prints the counts;
`npm run clock -- bookings` runs the booking clock once (sweeps and shoot reminders). The tool
refuses unless `FIRESTORE_EMULATOR_HOST` and `FIREBASE_AUTH_EMULATOR_HOST` point at a local host;
push is only logged.

```bash
export FIRESTORE_EMULATOR_HOST=127.0.0.1:8080 FIREBASE_AUTH_EMULATOR_HOST=127.0.0.1:9099 GCLOUD_PROJECT=<project>
npm run clock -- events
# eventClock: closed=0 completed=0 consentExpired=0 refunded=0 soonEvents=1 soonSent=1
# Lan's inbox now has "Chụp phố đêm bắt đầu ngày mai" (or "sau 2 ngày"); a second run sends nothing.
```
