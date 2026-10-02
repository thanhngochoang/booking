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

| Booking | Customer ↔ photographer | Status | `getContactLink` |
|---|---|---|---|
| `seed-booking-accepted` | Lan ↔ An | accepted | unlocked (all three channels) |
| `seed-booking-upcoming` | Lan ↔ An | upcoming | unlocked |
| `seed-booking-requested-binh` | Lan ↔ Bình | requested | `call` only; `zalo`/`whatsapp` → `not_found` |
| `seed-booking-cancelled` | Lan ↔ An | cancelled | `contact_locked` |
| `seed-booking-completed-recent` | Lan ↔ An | completed 3 days before seeding | unlocked |
| `seed-booking-completed-old` | Lan ↔ An | completed 40 days before seeding | `contact_locked` |

Try a call while the emulators run (from `app_flutter/firebase/functions`, with the project id
`scripts/backend-local.sh` printed). The script refuses to run unless the three emulator hosts
point at a local host, so export them first:

```bash
export FIRESTORE_EMULATOR_HOST=127.0.0.1:8080 FIREBASE_AUTH_EMULATOR_HOST=127.0.0.1:9099 \
  FUNCTIONS_EMULATOR_HOST=127.0.0.1:5001 GCLOUD_PROJECT=<project>
npm run try:contact -- lan.customer@seed.test seed-booking-accepted zalo
# 200 {"result":{"url":"https://zalo.me/84912000002"}}
```
