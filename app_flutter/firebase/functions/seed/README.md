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
| `binh.unverified@seed.test` | `seed-photographer-binh` | photographer | not verified, Đà Nẵng; Gọi only; `+84987000001` |
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

## Earnings and payouts (plan 10b)

| Data | Owner | Notes |
|---|---|---|
| `payoutAccounts/{uid}` + `accounts/seed-account-an-1` | An | VCB, `0123456789` (stored encrypted with the emulator key in `.secret.local`; the owner view shows `•••• 6789`), holder `NGUYEN VAN AN` |
| Payout `seed-payout-an-1` | An | `paid`; its payment (`seed-payment-seed-booking-completed-old`) is `paid_out`, with a `payout_paid` ledger entry |
| `seed-booking-disputed` | Lan ↔ An | completed 10 hours before seeding; payment `disputed`, reason "Ảnh giao thiếu so với gói" |
| `earnings/{uid}` + `items/*` | An, Bình | the projection, computed with the same pure functions as the triggers (An: held 3 × 450 000, soon 450 000, received 450 000) |
| Payout account | Bình | none (the S06.05 add-account card) |

## Notifications and badges

| Data | Owner | Notes |
|---|---|---|
| Inbox rows (`users/{uid}/notifications/*`) | Lan | 5 rows: booking accepted (unread), 24 h reminder (read), refund (read), declined (read, 12 days old), grouped chat with 2 messages (unread) |
| Inbox rows | An | booking request (unread), new review (read) |
| `users/{uid}/private/inbox` | Lan, An | `unreadCount` 2 and 1, matching the unread rows |
| Earned badges | An | `top_rated`, `shoots_10`, `complete_profile`; progress `punctual` 3/5, `shoots_50` 12/50 |
| Earned badges | Lan | `loyal_customer`; progress `sharer` 2/5, `detailed_reviewer` 3/5 |
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

`npm run awards -- --help` lists the commands. Against the emulators set
`FIRESTORE_EMULATOR_HOST` and `FIREBASE_AUTH_EMULATOR_HOST`; against a real project set
`GOOGLE_APPLICATION_CREDENTIALS` (a service account key). `show` also needs `STORAGE_BUCKET`
(or `FIREBASE_STORAGE_BUCKET`) and credentials that can sign URLs. `--actor` is a user with the
admin claim, e.g. `seed-staff-admin` locally.

## Staff CLI for payouts

`npm run payouts -- --help` lists the commands: `due` (payees with released money and open
payouts), `show <payoutId>` (the account is printed masked, `•••• 6789`), and
`create <payeeId>`, `execute <payoutId>`, `hold <payoutId> "<reason>"`, `resume <payoutId>`, each
with `--actor <uid>` of an admin (`seed-staff-admin` locally). Against the emulators set
`FIRESTORE_EMULATOR_HOST` and `FIREBASE_AUTH_EMULATOR_HOST`; the key comes from `.secret.local`.
Against a real project set `GOOGLE_APPLICATION_CREDENTIALS` and `PAYOUT_ACCOUNT_KEY`. `execute`
works only with the fake gateway (emulators or `PAYOUTS_MODE=fake`): no real bank adapter exists.

```bash
npm run payouts -- due
npm run payouts -- create seed-photographer-an --actor seed-staff-admin   # batches An's released payment (completed-recent)
```

## Photo events (plan 10c)

| Data | Owner | Notes |
|---|---|---|
| `seed-event-an-free-photowalk` | An | open, free ("Không thu phí"), starts in 8 days, capacity 20, 1 seat taken; group chat `event_seed-event-an-free-photowalk` (An, Lan) |
| `seed-event-an-paid-workshop` | An | open, 250 000 VND per ticket, starts in 15 days, capacity 12 (registering answers `not_eligible` until the paid path lands) |
| `seed-registration-lan-free-walk` | Lan | free registration to the walk: `paid`, `contactEligible: false`, ticket `VE-LANA-0000`, no `private/contact` snapshot (the host never gets Lan's phone) |

Each event also has its hashtag guard (`event_hashtags/*`), the booked day in An's availability, and the registration its `ticket_codes/*` entry.
