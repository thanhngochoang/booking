# Phase 2 · Toàn bộ app chạy trên API Node.js + PostgreSQL (spec #170)

- **Issue:** #170 (cha: #90). **Ngày:** 2026-11-20. **Trạng thái:** bản nháp chờ chủ sở hữu duyệt.
- **Thay cho:** thứ tự "ra mắt trên Firebase rồi mới chuyển" của `data-model/README.md` §6 (bậc 2, 3 và 5), và
  plan cũ `plans/2026-10-01-backend-phase2-selfhosted-postgres.md` (lát đầu tiên, đã làm xong).
- **Đọc cùng:** `data-model/README.md` (quy ước, cổng, ma trận phân quyền §4, use case §5),
  `data-model/relational-schema.md` (DDL đích, ánh xạ Firestore §3, dẫn xuất §4, thứ tự khoá ngoại §5),
  `data-model/domain-model.md`, và booking-be `AGENTS.md`.

## 1. Vì sao

Chủ sở hữu quyết định ngày 2026-11-15:

- "ra mắt chạy luôn trên API Node.js + PostgreSQL";
- "Cloud Functions chỉ chạy test khả thi, mọi logic chuyển hết về booking be, các dịch vụ của google chỉ dùng
  để gửi tin nhắn hoặc để authen";
- "tất cả tính năng Phase 1 đều phải chạy được" khi ra mắt;
- dashboard staff (#163–#169) xây trên API, không xây trên callable Firebase.

Hôm nay app chỉ gọi API ở 4 repository (hồ sơ, liên hệ khách, liên hệ thợ, link liên hệ). Mọi tính năng
khác đọc, ghi và nghe realtime qua Firestore, Cloud Functions và Firebase Storage. Spec này nói cách chuyển
tất cả sang API, và chốt các hợp đồng dùng chung (mục 6). Nhờ đó các plan cho từng cụm được viết song song
(skill `plan-in-issue`), mà không plan nào phải tự đặt ra một quy ước khác với plan bên cạnh.

## 2. Mục tiêu, không làm, phản mục tiêu

**Mục tiêu**

1. Mọi màn S01–S30 và dashboard staff chạy với `BACKEND=selfhosted`, không gọi Firestore, Functions hay
   Firebase Storage.
2. Google chỉ còn hai việc:
   - Firebase Auth: đăng nhập, phát ID token;
   - FCM: gửi push.
3. Luật nghiệp vụ trong `packages/domain` được dùng lại nguyên vẹn. API là lớp adapter mỏng, giống vai trò
   của Functions hôm nay.
4. Mỗi cụm có test chứng minh:
   - adapter PostgreSQL hành xử giống fake bộ nhớ;
   - adapter HTTP của app hành xử giống fake của app.

**Không làm (trong spec này)**

- Không làm công cụ chuyển dữ liệu Firestore sang PostgreSQL, không chạy song song, không so khớp
  (#184, #185). Lý do: chưa có dữ liệu thật; dữ liệu seed được viết lại cho PostgreSQL.
- Không tích hợp nhà cung cấp thật (cổng thanh toán, chi trả, eKYC, OTP, tra mã số thuế). Các adapter giả
  hôm nay được chuyển nguyên sang API. Tích hợp thật là các issue riêng.
- Không làm offline-first. App không còn bộ đệm ngoại tuyến của Firestore; mất mạng thì hiện lỗi và thử lại
  như mọi lời gọi HTTP.
- Không viết lại sang Rust hay Go (#99, Phase 3). Không dùng GraphQL. Không dùng Row-Level Security.
- Không làm tính năng mới trong các plan chuyển cụm. Các tính năng Phase 2 (#191, #195, #196, #213, #327,
  #329) là plan riêng, chạy sau cụm của chúng.

**Phản mục tiêu (dù chạy được vẫn coi là hỏng)**

- Viết lại luật nghiệp vụ trong `src/` của API thay vì gọi `packages/domain`. Ví dụ: tính tiền hoàn, chuyển
  trạng thái booking, quyền liên hệ.
- Hai nguồn sự thật cho cùng một dữ liệu trong cùng một môi trường. Ví dụ: booking ở PostgreSQL nhưng số đếm
  của nó do trigger Firestore giữ.
- Tính năng mới chỉ chạy trên Firebase kể từ ngày spec này được duyệt.
- Mỗi cụm tự đặt ra một kiểu realtime, kiểu lỗi, kiểu phân trang hay kiểu job riêng.

## 3. Hiện trạng (kiểm kê 2026-11-15)

| Cụm | Functions (callable · trigger · lịch) | Method port domain | Port app cần HTTP | `watch*` trong app |
|---|---|---|---|---|
| Booking & studio (S04–S06, S26, S27, giá ngày S08, điểm chụp S29, ban quản lý S30) | 57 · 5 · 3 | ~206 | 9 | 32 |
| Tiền & xác minh (S21, S22, chi trả) | 21 · 3 · 2 + webhook | ~95 | 4 | 7 |
| Sự kiện (S11, S12) | 16 · 1 · 2 | ~69 | 4 | 15 |
| Tài khoản & hồ sơ (S01, S03, S09, S19, S20) | 10 · 3 · 0 | ~46 | 14 (4 đã có) | 13 |
| Nội dung & khám phá (S02, S10, S24, S25) | 10 · 8 · 3 | ~45 | 9 | 4 |
| Chụp ngay & đăng việc (S13–S16) | 21 · 5 · 0 | ~44 | 2 | 12 |
| Bàn giao, đánh giá, khiếu nại | 8 · 2 · 0 + 1 trigger Storage | ~31 | 3 | 5 |
| Chat & thông báo (S07, S17) | 3 · 4 · 1 | ~20 | 4 | 6 |
| Staff (S23) | 6 | ~14 | dashboard | — |
| **Tổng** | **196 hàm (152 callable, 31 trigger Firestore, 1 trigger Storage, 11 lịch, 1 webhook)** | **~580** | **48 mới** | **96** |

**Đã có trên API:**
- 12 endpoint (`health`, `me`, `users`, `photographers`, `contact-links`) và 5 migration;
- xác minh Firebase ID token (`jose`, JWKS; có chế độ `firebase-emulator` cho máy local);
- mã lỗi lấy từ `ERROR_CODES` của domain, kèm bảng mã HTTP (`src/errors.ts`);
- OpenAPI (`api/openapi.yaml`) là nguồn của route, schema và kiểu TypeScript;
- Kysely trên `pg`, test bằng Vitest và Testcontainers;
- Docker Compose gồm PostgreSQL 16 + PostGIS, Auth emulator, API và seed.

**Trong domain:**
- Khoảng 30 interface `…Store`, mỗi cái có `runTransaction(fn: (tx) => …)`. Firestore buộc mọi lệnh đọc
  trong `tx` đứng trước lệnh ghi đầu tiên, và một số fake bộ nhớ cũng kiểm điều này.
- Lệnh ghi `put…`/`delete…` phần lớn trả `void` (khoảng 71 cái); khoảng 7 cái trả `Promise<void>`.
- Một số method của Store nằm ngoài `tx` nhưng có transaction riêng (ví dụ `setReadOnly` trong
  `chat_firestore.ts`). Một số method là phép cộng nguyên tử (`incrementUnread`, dùng `FieldValue.increment`).
- `RetryableConflict` yêu cầu adapter chạy lại transaction.
- Fake bộ nhớ (`memory_*_store.ts`) và "world" test (`test/support/*_world.ts`) có cho mọi cụm.
- Functions nối domain qua `infra/<cụm>_firestore.ts` (adapter) và `infra/live_<cụm>.ts` (wiring).

**Những điểm khó đã biết:**
- Khoảng 32–34 trigger (đếm theo export hay theo đăng ký) đang giữ số đếm, hình chiếu, thông báo và push.
- `bookingClock` chạy khoảng 15 bước thuộc 6 cụm. `pruneNotifications` còn xoá tài khoản và tệp xuất.
- Một số phần chưa có lớp domain:
  - xoá tài khoản, xuất dữ liệu;
  - pipeline watermark (`triggers/delivery_upload.ts`, `infra/watermark.ts`);
  - phát hiện câu khách (`staff_flags` trong `booking_write`);
  - vài handler viết thẳng trong `index.ts`.
- App ghi thẳng Firestore ở 19 đường dẫn, và có 11 đường dẫn Storage cho client ghi.
- Khoảng 20 model trong app import `cloud_firestore`. Danh sách chat mở một listener cho mỗi cuộc chat.
- `ApiClient` của app chưa có DELETE và SSE. `local_watch.dart` (`fetchThenLocal`) không thấy thay đổi đến từ
  máy khác.

## 4. Các cách đã cân nhắc

**Cách chuyển (người viết spec chọn):**

- **A. Adapter PostgreSQL cho chính các port của domain. API handler mỏng gọi đúng use case mà callable đang
  gọi. (Chọn.)** Dùng lại khoảng 45 nghìn dòng domain, và các world test sẵn có làm chuẩn hành vi. Phần phải
  viết chủ yếu là adapter, endpoint và job. Giá phải trả: mô hình transaction của domain phải được dựng lại trên
  PostgreSQL (mục 6.2).
- **B. Viết API theo kiểu SQL trước, như lát đầu tiên (`src/use-cases/get-contact-link.ts`).** Truy vấn gọn
  hơn cho từng màn, nhưng phải viết lại luật nghiệp vụ, đúng phản mục tiêu số 1. Lát đầu tiên chỉ đủ nhỏ để
  làm vậy.
- **C. Giữ Firestore làm kho, API chỉ là lớp bọc.** Không bỏ được Google, trái quyết định của chủ sở hữu.

**Cách lên plan (chủ sở hữu chọn ngày 2026-11-20):** viết spec này trước, chốt hợp đồng chung, rồi các
subagent viết plan song song và đăng vào issue. Hai cách bị bỏ:
- để mỗi agent tự quyết rồi đối chiếu sau;
- viết plan nền tảng trước rồi mới viết plan cụm.

## 5. Kiến trúc đích

```
App Flutter ──HTTPS──► API (Fastify) ──► PostgreSQL 16 + PostGIS
     │   ▲                 │   ▲            ▲
     │   └──── SSE ────────┘   └ LISTEN ────┤ NOTIFY (trong transaction)
     │                                      │
     └─ PUT/POST ảnh ──► S3-compatible ◄── Worker (pg-boss: job, lịch; sharp; FCM)
Dashboard Next.js (BFF) ──► API /v1/staff/…
Firebase Auth: chỉ đăng nhập và ID token.   FCM: chỉ push.
```

- **Một image Node, hai vai trò:** `ROLE=api` (HTTP và SSE) và `ROLE=worker` (pg-boss và lịch). Cùng mã
  nguồn, cùng migration. Chạy được nhiều bản API; chỉ chạy một bản worker cho phần lịch (pg-boss tự khoá).
- **Cùng một transaction:** dữ liệu, sự kiện realtime (`pg_notify`) và job (pg-boss) được ghi chung. Chỉ khi
  commit thì realtime mới phát và job mới chạy. Không cần bảng outbox riêng.

## 6. Hợp đồng chung (mọi plan phải theo)

### 6.1 Bố cục mã trong booking-be

```
src/
  app.ts, server.ts, worker.ts          # worker.ts mới: đăng ký job và lịch
  platform/                             # #172–#174: dùng chung, không chứa luật nghiệp vụ
    db/ (database.ts gộp kiểu bảng, tx.ts, migrate.ts)
    http/ (errors.ts, auth.ts, staff-gate.ts, pagination.ts, idempotency.ts)
    realtime/ (emit.ts, sse.ts, audience.ts)
    jobs/ (boss.ts, enqueue.ts, schedules.ts)
    media/ (s3.ts, files.ts, url-resolver.ts)
    push/ (fcm.ts)
  modules/<cụm>/                        # mỗi plan cụm chỉ sửa trong thư mục của mình
    tables.ts                           # kiểu Kysely của các bảng cụm này
    pg/<tên>_store.ts                   # adapter PostgreSQL cho port domain (giống infra/<cụm>_firestore.ts)
    live.ts                             # nối domain với adapter (giống infra/live_<cụm>.ts)
    routes.ts                           # endpoint
    jobs.ts                             # job và lịch của cụm
api/
  openapi.yaml                          # gốc, chỉ $ref
  paths/<cụm>.yaml, schemas/<cụm>.yaml  # mỗi cụm một tệp, để PR song song không đụng nhau
migrations/<timestamp>_<cụm>_<việc>.sql
```

- **Tên cụm** (dùng cho thư mục, tiền tố job, tiền tố topic): `accounts`, `chat`, `content`, `money`,
  `booking`, `delivery`, `events`, `instant`, `staff`, `platform`.
- **Chỗ duy nhất các plan cùng sửa:** `src/app.ts`, `src/worker.ts`, `api/openapi.yaml` và
  `src/platform/db/database.ts`, mỗi tệp chỉ thêm một dòng đăng ký. Xung đột ở đây giải bằng rebase.

### 6.2 Store PostgreSQL và transaction

- Mỗi port `…Store`/`…Tx` của domain có một adapter `modules/<cụm>/pg/…_store.ts`. Adapter không chứa luật
  nghiệp vụ.
- **Một transaction cho mỗi request và mỗi job ("unit of work")**, trong `platform/db/tx.ts`:
  - Handler HTTP và handler job chạy trong `unitOfWork(fn)`. Hàm này mở một transaction `SERIALIZABLE` trên một
    kết nối riêng, và đặt nó vào `AsyncLocalStorage`.
  - `runTransaction` của mọi adapter PostgreSQL **nhập vào** transaction đang có, không mở transaction mới. Vì
    vậy một use case đụng nhiều Store (booking + thanh toán + chat + lịch bận) vẫn là một khối nguyên tử.
  - `emit(…)` (6.6) và `enqueue(…)` (6.7) cũng lấy transaction từ `AsyncLocalStorage`; domain không phải biết
    tới chúng. Một test cấm gọi chúng khi không có unit of work.
  - Gọi `runTransaction` ngoài unit of work (script, test) thì nó tự mở unit of work riêng.
- **Chạy lại:** lỗi `40001`/`40P01` hoặc `RetryableConflict` thì chạy lại **cả unit of work**, tối đa 5 lần, nghỉ
  ngẫu nhiên 10–100 ms. Hết số lần thì trả `conflict`. Vì vậy:
  - lời gọi ra ngoài trong một use case (`PaymentGateway`, `PayoutGateway`, eKYC, OTP) phải mang khoá
    idempotency;
  - #172 có một task rà các lời gọi ra ngoài nằm trong `runTransaction` của domain và ghi lại danh sách.
- **Lệnh ghi:** `put…`/`delete…` gửi câu lệnh ngay trên kết nối của transaction. `pg` chạy câu lệnh theo đúng
  thứ tự gửi, nên lệnh đọc sau đó thấy được dữ liệu vừa ghi. Adapter giữ các promise chưa chờ và chờ hết trước
  `COMMIT`; một lệnh ghi lỗi làm hỏng cả transaction. Ghi theo dạng `INSERT … ON CONFLICT DO UPDATE`/`DELETE`.
  Phép cộng nguyên tử viết `UPDATE … SET n = n + $1`, không đọc rồi ghi.
- **Khoá ngoại** khai báo `DEFERRABLE INITIALLY DEFERRED`, nên thứ tự ghi không phải theo relational-schema §5.
- **Kết nối:** API và worker nối thẳng PostgreSQL (pool của `pg`). Không đặt PgBouncer ở chế độ transaction
  phía trước, vì nó làm hỏng `LISTEN`, pg-boss và transaction dài. Đây là ràng buộc cho #171.
- **Hình dạng dữ liệu:**
  - Domain giữ hình dạng "tài liệu" của nó. Adapter tách và ghép theo các bảng của relational-schema §2,
    theo đúng ánh xạ §3.
  - Giá trị lồng nhau không bao giờ bị truy vấn được lưu `jsonb`. Mọi trường dùng để lọc, sắp xếp hay đếm
    phải là cột.
  - Hình chiếu chỉ tồn tại vì Firestore không join được trở thành view hoặc truy vấn. Ví dụ:
    `payer_payment_rows`, `managedSpotIds`, `catalog/explore`.
- **Truy vấn ngoài transaction** (`dueFor…`, danh sách) là method thường của Store, có `LIMIT` và chỉ mục
  tương ứng.
- **Địa lý:** giữ `lat`, `lng`, `geohash` như relational-schema, và thêm cột
  `geog geography(Point,4326)` kèm chỉ mục GiST. Truy vấn "gần đây" dùng `ST_DWithin`. Port `GeoIndex` thay
  việc quét theo ô geohash.

### 6.3 Bảng và migration

- **Nguồn DDL là `relational-schema.md`.** Plan nào cần đổi lược đồ thì sửa tài liệu đó trong cùng PR
  (repo booking) và ghi lý do.
- **Quy ước của relational-schema §1 giữ nguyên:**
  - id `text`, dùng ULID (`ulidx`); thời điểm `timestamptz` UTC; tiền `bigint` VND;
  - enum là `text` + `CHECK`;
  - có `created_at`, `updated_at`, `deleted_at`; `version int` cho các bản ghi bị sửa đồng thời;
  - tên ràng buộc `pk_`, `fk_`, `ck_`, `ux_`, `ix_`;
  - trigger `set_updated_at` là trigger cơ sở dữ liệu **duy nhất** được phép.
- **Tên tệp migration:** theo kiểu sẵn có, `<mili-giây epoch>_<cụm>_<việc>.sql` (như `1790812800001_accounts.sql`),
  lấy thời điểm lúc viết.
  - `node-pg-migrate` đổi sang `checkOrder: false` (hôm nay `src/db/migrate.ts` để `true`), vì các PR song song merge không theo thứ tự tên.
  - Một migration chỉ được tham chiếu bảng của `platform` và của những cụm đứng trước nó ở mục 7.
- **Migration không được sửa sau khi đã merge.** Muốn đổi thì viết migration mới.

### 6.4 API HTTP

- **Tiền tố `/v1`. Mỗi callable thành đúng một endpoint**, với `operationId` = tên callable. Nhờ đó adapter
  của app thay `httpsCallable('x')` bằng `operationId: x` một cách máy móc.
- **Đặt tên đường dẫn theo tài nguyên:**
  - đọc: `GET /v1/<tài-nguyên>[/{id}]`;
  - tạo: `POST /v1/<tài-nguyên>`;
  - lệnh: `POST /v1/<tài-nguyên>/{id}/<động-từ>`, ví dụ `acceptBooking` → `POST /v1/bookings/{id}/accept`;
  - sửa một phần: `PATCH`; xoá: `DELETE`.
  - Mỗi plan có bảng "callable → endpoint" và bảng "đường đọc Firestore → endpoint GET".
- **Lỗi:**
  - Thân lỗi giữ dạng hiện có `{ "error": { "code", "message", "details"? } }`.
  - `code` lấy từ `ERROR_CODES` của domain cộng `unauthenticated`, `internal`.
  - Mã mới thì thêm vào domain và vào `HTTP_STATUS`. Không trả mã chỉ API mới có.
- **Phân trang:** `?after=<con trỏ mờ>&limit=<1..100, mặc định 20>` trả `{ "items": [...], "next": string|null }`.
  Danh sách chỉ nối thêm (tin nhắn, thông báo, dòng thời gian) còn nhận thêm `?since=<con trỏ>` để lấy phần mới.
- **Idempotency:** lệnh có tiền hoặc tạo bản ghi nhận header `Idempotency-Key`.
  - Lớp chung (`platform/http/idempotency.ts`) giữ bảng `idempotency_keys(user_id, key, operation_id,
    request_hash, status, response, created_at)` trong 48 giờ.
  - Gọi lại với cùng khoá và cùng thân: trả lại đúng phản hồi cũ. Cùng khoá nhưng thân khác: trả
    `invalid_argument`.
  - Use case đã có khoá riêng trong domain (thanh toán, chụp ngay, vé, tin nhắn `clientId`) vẫn giữ khoá đó;
    lớp chung không thay nó.
- **Ghi thẳng của app** (19 đường dẫn Firestore mà app ghi không qua callable): mỗi đường dẫn thành một endpoint
  `PUT`/`PATCH`/`DELETE`.
  - Phần kiểm tra đang nằm trong `firestore.rules` được chuyển thành hàm thuần trong domain, có test.
  - Mỗi plan có bảng "đường ghi thẳng → endpoint".
- **Webhook nhà cung cấp:** `POST /v1/webhooks/<provider>`, không cần token nhưng bắt buộc kiểm chữ ký.
  Dùng lại `fake_webhook` cho tới khi có nhà cung cấp thật.
- **`bodyLimit` 16 KiB** giữ nguyên. Ảnh không bao giờ đi qua API (mục 6.8).

### 6.5 Xác thực và phân quyền

- **Người dùng:** Firebase ID token qua `Authorization: Bearer`, như hôm nay. Vai trò khách/thợ (`role`) đọc
  từ bảng `users`.
- **Khoá người dùng:** `users.id` là uid của Firebase (`text`), là ngoại lệ duy nhất của quy tắc ULID. Seed giữ
  nguyên uid của tài khoản thử.
- **Tạo tài khoản:** dòng `users` được tạo ở lần gọi đầu tiên (`PUT /v1/me`, upsert). Cách này thay trigger
  `user_created`.
- **Phân quyền thay cho Firestore rules:**
  - Ma trận `data-model/README.md` §4 là chuẩn.
  - Mỗi handler kiểm quyền trước khi gọi use case, hoặc để use case tự kiểm như đã có trong domain.
  - Truy vấn đọc luôn lọc theo người gọi trong SQL.
  - Mỗi dòng ma trận mà cụm đụng tới có ít nhất một test "được" và một test "bị từ chối".
- **Staff:**
  - Bảng `staff_members`, `audit_log`, `staff_approvals` theo relational-schema.
  - **`staff_members` là nguồn sự thật của vai trò staff.** Đây là thay đổi so với #162, nơi vai trò đọc từ
    custom claim `staffRole` (`callables/staff.ts`). Cột `users.staff_role` (migration accounts) bị bỏ bằng một
    migration của #172, và API không đặt custom claim nữa.
  - **Cổng staff (#172):** staff có trong `staff_members` và đang hoạt động; token có
    `firebase.sign_in_second_factor == 'totp'`; và `auth_time` của token lớn hơn
    `staff_members.sessions_valid_after`. Cột này thay cho `sessions.isActive`. Thu hồi phiên nghĩa là đặt cột
    đó bằng `now()`.
  - Lối vượt TOTP `MFA_DEV_BYPASS` chỉ có khi `AUTH_MODE=firebase-emulator`, vì Auth emulator không có TOTP.
  - Endpoint staff nằm dưới `/v1/staff/<cụm>/…`. Hành động tiền và hành động nhạy cảm dùng đúng cơ chế duyệt
    hai người `APPROVAL_KINDS` của domain.

### 6.6 Realtime (SSE)

- **Kết nối:** một luồng cho mỗi phiên đăng nhập, `GET /v1/events` (`text/event-stream`, token trong header).
  - Máy chủ gửi comment giữ kết nối mỗi 25 giây.
  - Máy chủ đóng luồng khi token hết hạn; app nối lại bằng token mới.
- **Sự kiện chỉ báo "có thay đổi", không mang dữ liệu:**
  ```
  event: change
  data: {"topic":"booking:01JD…","kind":"booking.updated"}
  ```
  App gọi lại endpoint GET tương ứng. Không phát lại sự kiện cũ: khi nối lại, mọi watch đang mở tự tải lại.
- **Topic:** `<cụm-thực-thể>:<id>` cho một tài nguyên, `user:<uid>:<danh-sách>` cho danh sách riêng của một
  người. Ví dụ: `user:<uid>:bookings`, `user:<uid>:notifications`, `chat:<id>`, `event:<id>:seats`.
  - Mỗi plan cụm liệt kê topic của mình trong bảng "watch → topic → endpoint".
- **Phát:** `emit(tx, topic, audience)` gọi `pg_notify('nag_events', …)` trong cùng transaction.
  - `audience` là một trong ba dạng: `{ uids: [...] }`, `{ resolver: '<tên>' }` (nhóm lớn như chat sự kiện;
    API tra thành viên qua `audience.ts`) hoặc `{ public: true }` (số ghế, số đếm công khai).
  - Payload dưới 7.000 byte; danh sách lớn thì dùng `resolver`.
- **Phía API:** mỗi tiến trình API giữ một kết nối `LISTEN`, chuyển sự kiện tới các luồng của người nhận.

### 6.7 Job, lịch và thay 32 trigger

- **pg-boss** chạy trong schema `pgboss`. Đẩy job bằng `enqueue(tx, '<cụm>.<việc>', data, opts)`, đi cùng
  transaction của thay đổi.
  - Handler phải chịu được việc chạy nhiều lần (at-least-once): kiểm trạng thái hoặc dùng khoá idempotency.
  - Thử lại 5 lần, backoff mũ; job hỏng thì vào hàng `failed` để staff xem.
- **Lịch:** `boss.schedule('<cụm>.<việc>', cron, {}, { tz: 'Asia/Ho_Chi_Minh' })`, cùng nhịp với Functions
  hôm nay.
  - `bookingClock` được tách thành từng bước riêng, mỗi bước một job tên `<cụm>.<bước>` thuộc đúng cụm của nó.
  - `pruneNotifications` cũng tách thành ba phần: tỉa thông báo, xoá tài khoản đến hạn, tỉa tệp xuất.
- **Mỗi trigger Firestore được xếp vào đúng một loại**, và plan cụm phải có bảng "trigger → loại → nơi làm":
  1. **Trong transaction:**
     - số liệu mà màn hình đọc ngay sau khi ghi (đếm ghế, `application_count`, `last_message_*`);
     - bất biến (lịch bận `availability_days`).
     - Gọi hàm domain tương ứng ngay trong `runTransaction` của use case.
  2. **Job sau commit:**
     - thông báo, push, email, ảnh;
     - tính lại điểm, thống kê, huy hiệu;
     - đồng bộ sang cụm khác.
     - Đẩy bằng `enqueue(tx, …)`.
  3. **Bỏ:** trigger chỉ để giữ một hình chiếu Firestore mà SQL truy vấn được (view hoặc truy vấn). Ghi rõ
     view hoặc truy vấn thay thế.
- **Không có trigger PL/pgSQL nghiệp vụ.** Có job đối soát định kỳ cho mỗi số đếm được lưu, theo cột "Cách
  giữ" của relational-schema §4.
- **Phần chưa có lớp domain** (xoá tài khoản, xuất dữ liệu, watermark, `staff_flags`, handler trong
  `index.ts`): plan cụm sở hữu phần đó phải đưa luật vào `packages/domain` trước (có test), rồi mới viết
  adapter.

### 6.8 Ảnh và tệp

- **Lưu trữ:** kho S3-compatible. Local dùng MinIO trong Docker Compose. Nhà cung cấp thật do #171 chọn.
- **Tải lên bằng presigned POST:**
  1. `POST /v1/files { purpose, contentType: "image/jpeg", size }` → `{ fileId, upload: { url, fields } }`.
     - Chính sách đã ký ép `Content-Type` và `content-length-range` theo bảng `ImagePurpose` của
       `data-model/README.md` (mục "Ảnh tải lên").
     - Khoá `<purpose>/<ownerId>/<ulid>.jpg`. Bản ghi `files` ở trạng thái `pending`.
  2. App gửi multipart thẳng tới kho, không qua API.
  3. `POST /v1/files/{id}/complete`: API kiểm đối tượng bằng `HEAD`, rồi đẩy job `media.process`. Job này mã
     hoá lại bằng `sharp` (xoá siêu dữ liệu lần nữa, đo kích thước, blurhash, đóng dấu mờ cho
     `deliverySample`), rồi đặt `files.status = ready`.
- **Tham chiếu và URL:**
  - Thực thể tham chiếu `file_id`, không lưu URL.
  - API trả URL do `MediaUrlResolver` dựng: purpose công khai dùng `PUBLIC_MEDIA_BASE/<khoá>`; purpose riêng
    tư dùng presigned GET 1 giờ, sau khi đã kiểm quyền xem.
- **App:** `MediaUploader` và `MediaUrlResolver` có bản HTTP. 11 đường dẫn Storage và các test
  `storage_rules_limits_sync_test` được thay bằng test đồng bộ bảng `ImagePurpose` với chính sách POST của API.

### 6.9 Thông báo và push

- **Lưu trong bảng:** thông báo trong app nằm ở `notifications`. Số chưa đọc là truy vấn, kèm topic
  `user:<uid>:notifications`.
- **Push:**
  - Token thiết bị ở `push_tokens`, đăng ký qua `PUT /v1/me/devices/{installationId}`.
  - Job `platform.push` gửi FCM bằng `firebase-admin`. Token hỏng thì bị xoá.
- **Phát thông báo:** use case tạo dòng `notifications` trong transaction, rồi `enqueue` push. Một cụm không
  được gửi FCM trực tiếp.

### 6.10 App Flutter

- **`ApiClient`:**
  - thêm `delete`, header `Idempotency-Key`, và tham số query;
  - lỗi vẫn ánh xạ `code` vào ngoại lệ của từng repository như hôm nay.
- **`RealtimeChannel`** (mới, `lib/data/http/`): một luồng SSE dùng chung, tự nối lại có backoff, có
  `Stream<ChangeEvent> on(String topic)`.
- **`watchQuery<T>(topics, fetch)`** (mới):
  - tải lần đầu, tải lại khi có sự kiện của một topic liên quan và khi nối lại;
  - gộp các sự kiện đến dồn trong 300 ms; huỷ đăng ký khi không còn người nghe.
  - Mọi `watch*` của adapter HTTP dùng helper này. `local_watch.dart` bị bỏ.
- **Adapter:**
  - Mỗi port có `Http…Repository` đặt cạnh bản Firestore, và được chọn qua `BackendConfig`.
  - `SelfhostedRepo` mở rộng thêm một mã cho mỗi cụm, tên trùng tên cụm ở mục 6.1.
- **Bỏ phụ thuộc Firestore khỏi model:**
  - plan cụm bỏ `cloud_firestore` khỏi model của cụm mình (`Timestamp`, `GeoPoint`, `DocumentReference`);
  - mapping JSON đi qua `wire.dart`, ISO-8601 UTC.
- **Chat:** danh sách chat là một endpoint và một topic `user:<uid>:chats`, không mở một listener cho mỗi chat.

### 6.11 Kiểm thử (mỗi plan cụm phải có)

1. **Bộ test hợp đồng port** (`packages/domain/test/contracts/<store>.contract.ts`): một bộ test, chạy với fake
   bộ nhớ (trong domain) và với adapter PostgreSQL (trong API, Testcontainers). Có cả test "đọc trước, ghi sau"
   và test chạy lại khi xung đột.
2. **Test endpoint** (Vitest + Testcontainers): mỗi endpoint có trường hợp thành công, sai đầu vào, không đăng
   nhập, và từ chối theo ma trận quyền. Lệnh có tiền thêm test gọi lại với cùng `Idempotency-Key`.
3. **Test job:** mỗi job chạy hai lần cho cùng một kết quả. Mỗi lịch có test chọn đúng bản ghi đến hạn.
4. **Test realtime:** mỗi lệnh ghi phát đúng topic cho đúng người nhận.
5. **App:**
   - adapter HTTP qua cùng bộ test với fake của app, dựa trên `test/data/contracts/contract-world.json`;
   - test drift so `openapi.yaml` (bản gộp, snapshot ở `test/data/contracts/`) với các `operationId` app dùng.
6. **Domain:** `npm test` của `packages/domain` vẫn xanh. Không test domain nào bị xoá để cho qua.

### 6.12 Môi trường local và seed

- **`docker compose up` của booking-be chạy:** `db`, `auth` (emulator), `minio`, `migrate`, `seed`, `api`,
  `worker`, `adminer`. App chạy với `BACKEND=selfhosted BASE_URL=…` cùng Auth emulator.
- **Seed:** mở rộng `src/tools/contract-world.ts` theo cụm, cùng tài khoản và cùng tên với seed Firebase
  (`firebase/functions/seed/README.md`), để kịch bản thử tay không đổi. Chỉ dùng giá trị thử.
- **Cấu hình:** app đọc từ `GET /v1/config` (#323): ngân hàng, khu vực, giới hạn tải lên, danh mục, chính sách
  tiền. Không còn hằng số trùng giữa app và backend.

## 7. Đơn vị việc, thứ tự, phụ thuộc

Mỗi dòng là một issue, plan đăng vào chính issue đó. Một cụm chỉ phụ thuộc vào những dòng đứng trên nó.

| # | Issue | Phạm vi | Bị chặn bởi |
|---|---|---|---|
| 1 | #172 Nền tảng API | Mục 6.1–6.5:<br>• khung `platform/`, store và transaction;<br>• quy ước migration, tách OpenAPI;<br>• lỗi, phân trang, idempotency;<br>• cổng staff, bảng staff (`staff_members`, `audit_log`, `staff_approvals` cùng duyệt hai người);<br>• `ApiClient` mở rộng;<br>• bộ khung test hợp đồng port. | — |
| 2 | #173 Realtime, job, push | Mục 6.6, 6.7 (phần `platform/jobs`), 6.9:<br>• SSE và `emit`;<br>• pg-boss và vai trò worker;<br>• `push_tokens`, FCM, `notifications`;<br>• `RealtimeChannel`, `watchQuery` trong app. | 1 |
| 3 | #174 Ảnh và tệp | Mục 6.8:<br>• `files`, MinIO, presigned POST;<br>• `media.process` cùng watermark (đưa luật watermark vào domain);<br>• `MediaUploader`/`MediaUrlResolver` HTTP. | 1, 2 |
| 4 | #323 Cấu hình từ API | `GET /v1/config` và app đọc từ đó. | 1 |
| 5 | #175 Tài khoản & hồ sơ | users, photographers, taxonomy, đã lưu và theo dõi (S19), báo cáo và chặn (S20), xoá tài khoản, xuất dữ liệu (đưa vào domain). | 2, 3 |
| 6 | #182 Chat & thông báo | Chat 1-1 và nhóm, tin nhắn, chưa đọc, ghim; danh sách chat một endpoint; màn thông báo S17. | 5 |
| 7 | #176 Nội dung & khám phá | Bài, album S24, giải thưởng S25, điểm chụp S29 (PostGIS), khám phá, gợi ý, huy hiệu. | 5 |
| 8 | #177 Tiền & xác minh | Thanh toán, sổ cái treo, webhook, hoàn, tài khoản chi trả, chi trả, thu nhập, xác minh S21; registry `SubjectSettler`. | 5 |
| 9 | #178 Booking & studio | Booking S04–S06, giá ngày S08, studio S26, tuyển thợ S27, ban quản lý và vé điểm S30, `staff_flags` (đưa vào domain), các bước `bookingClock` của booking. | 6, 7, 8 |
| 10 | #179 Bàn giao, đánh giá, khiếu nại | Bàn giao, mở khoá link, cà chua/gạch, khiếu nại S18, hỗ trợ. | 9 |
| 11 | #180 Sự kiện | S11, S12, vé, chat nhóm sự kiện, dòng thời gian. | 6, 8, 9 |
| 12 | #181 Chụp ngay & đăng việc | S13–S16, khớp thợ, theo dõi đường đi, heartbeat. | 6, 8 |
| 13 | #183 Dashboard trên API | BFF `apps/dashboard` gọi `/v1/staff/…`.<br>• Làm lại #163, #342, #343 trên API.<br>• Màn #164, #349 (xác minh, giải thưởng) cũng làm trên API. | 1, 8 |
| 14 | #165–#169 Màn staff còn lại | Mỗi issue một plan, trên API. | 13 + cụm của màn đó |
| 15 | #171 VPS, deploy | Compose production, Caddy, sao lưu PostgreSQL và kho ảnh, CI deploy. | 1 (song song với phần còn lại) |
| 16 | #186 Gỡ Firebase | Mục 9: xoá Functions, rules, adapter Firestore và Storage trong app, `cloud_firestore` trong `pubspec`; app mặc định `selfhosted`. | 5–14 |
| 17 | #191, #195, #196, #213, #327, #329 | Tính năng Phase 2, viết thẳng trên API. | cụm tương ứng |

- **Một issue quá lớn cho một plan** (đoán: #178, #177) được tách thành nhiều plan con. Plan đầu đăng ở issue
  cha; các plan con là sub-issue mới, mỗi sub-issue chứa plan của nó (`plan-in-issue`).
- **Chạy song song:** sau dòng 5, các dòng 6, 7, 8 chạy song song; sau đó 11 và 12 chạy song song với 10.

## 8. Mỗi plan cụm phải có

1. Danh sách callable, trigger, lịch, port, đường ghi thẳng và `watch*` của cụm, đếm từ mã nguồn. Mục 3 chỉ là con số ước lượng để so; nếu lệch thì ghi lại.
2. Bảng "callable → endpoint (`operationId`)", "đường đọc Firestore → endpoint GET" và "đường ghi thẳng → endpoint".
3. Bảng "trigger → loại 1/2/3 → nơi làm" (mục 6.7), và "lịch → job".
4. Bảng "watch → topic → endpoint" (mục 6.6), và các topic cụm phát ra.
5. Bảng và migration theo relational-schema (thay đổi lược đồ thì sửa tài liệu đó).
6. Các dòng ma trận quyền §4 mà cụm đụng tới, và test cho từng dòng.
7. Phần app:
   - adapter HTTP cho từng port;
   - mã `SelfhostedRepo`;
   - bỏ `cloud_firestore` khỏi model của cụm;
   - seed;
   - snapshot OpenAPI.
8. Tiêu chí xong: test mục 6.11 xanh. Với `BACKEND=selfhosted` và mọi cụm đứng trước đã xong, các màn của cụm
   chạy được trên máy thật với `docker compose up`.

## 9. Firebase trong lúc chuyển và sau đó

- **Đóng băng ngay khi spec được duyệt:** không thêm tính năng chỉ chạy trên Firebase. Sửa lỗi trên Firebase
  chỉ làm khi lỗi đó chặn việc thử tay.
- **Firebase vẫn chạy được tới #186,** để app dùng đủ tính năng trên emulator trong lúc chuyển.
  - Không hỗ trợ chạy lẫn, ví dụ booking ở PostgreSQL còn chat ở Firestore.
  - `SELFHOSTED_REPOS` chỉ dùng để thử một cụm cùng các cụm đứng trước nó.
- **#186 (Gỡ Firebase)** chạy khi mọi cụm xong:
  - xoá `firebase/functions`, rules, chỉ mục và cấu hình emulator, trừ Auth emulator;
  - bỏ adapter Firestore và Storage trong app, cùng `cloud_firestore`, `cloud_functions`, `firebase_storage`;
  - `BACKEND` mặc định là `selfhosted`, và bỏ `Backend.firebase`;
  - giữ `firebase_core`, `firebase_auth`, `firebase_messaging`.
- **#184, #185 và #340** không còn cần thiết theo quyết định "ra mắt trên API". Đóng hay giữ là việc của chủ
  sở hữu (mục 12).

## 10. Tài liệu cần cập nhật (trong PR của spec này)

- **`data-model/README.md`:**
  - §6: thay bậc thang di trú bằng một dòng trỏ sang spec này;
  - §8: ghi câu trả lời (PostgreSQL; TypeScript; ULID; SSE tự vận hành; giữ Firebase Auth làm IdP).
- **`AGENTS.md`, dòng "Server code":** Functions đóng băng; mã mới viết trong `src/` của booking-be theo spec
  này.
- **Milestone:** "Phase 2 · Backend Go + PostgreSQL" đổi tên thành "Phase 2 · Backend Node.js + PostgreSQL"
  (đổi trên GitHub, không phải trong repo).

## 11. Để lại cho người viết plan

- Tên bảng phụ, tên chỉ mục, và cách tách một tài liệu domain thành các dòng (trong khuôn khổ
  relational-schema).
- Cách gom và chia task trong plan; cụm nào cần tách thành plan con.
- Đường dẫn cụ thể của từng endpoint, theo quy tắc mục 6.4.
- Loại 1 hay 2 cho từng trigger, theo tiêu chí mục 6.7. Trường hợp lưng chừng thì chọn loại 2 và ghi lý do.

## 12. Quyết định

**Của chủ sở hữu:**
- ra mắt trên API;
- Google chỉ còn Auth và FCM;
- đủ tính năng Phase 1 khi ra mắt;
- dashboard trên API;
- plan nằm trong issue, viết song song sau spec này.

**Của người viết spec (chủ sở hữu có thể sửa):**
- dùng lại domain qua adapter PostgreSQL (cách A);
- `SERIALIZABLE` và chạy lại 5 lần; khoá ngoại `DEFERRABLE`;
- một unit of work cho mỗi request hoặc job, mọi Store nhập vào cùng transaction qua `AsyncLocalStorage`;
- ghi ngay trên kết nối của transaction, chờ hết trước `COMMIT`;
- `users.id` là uid Firebase, tạo tài khoản bằng `PUT /v1/me`;
- `staff_members` là nguồn vai trò staff, thu hồi bằng `sessions_valid_after`;
- bảng `idempotency_keys` giữ 48 giờ;
- nối thẳng PostgreSQL, không pooler ở chế độ transaction;
- SSE chỉ báo thay đổi, không phát lại;
- pg-boss, đẩy job trong transaction;
- presigned POST và MinIO;
- không có RLS;
- `checkOrder: false`;
- tách OpenAPI theo cụm;
- thứ tự ở mục 7;
- đóng băng Firebase, không chạy lẫn.

**Câu hỏi cho chủ sở hữu:** được bổ sung sau bước đọc thử của người dựng (builder check).
