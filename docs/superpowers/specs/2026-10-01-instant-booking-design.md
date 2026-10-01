# Chụp ngay: đặt nhiếp ảnh gia tức thì kiểu Uber

Ngày 2026-10-01. Bổ sung cho spec chính [`2026-10-01-remaining-screens.md`](2026-10-01-remaining-screens.md) (gọi là "spec chính"). Mục 3e.4 của spec chính ghi "ghép cặp tự động là sản phẩm khác, ngoài phạm vi v1"; spec này chính là sản phẩm đó và thay cho ghi chú ấy.

## 1. Mục tiêu và phạm vi

Khách cần nhiếp ảnh gia **ngay bây giờ** (buổi chụp bắt đầu trong 30–90 phút) ở chỗ mình đang đứng. Khách không chọn người: hệ thống tìm một nhiếp ảnh gia phù hợp ở gần, gửi lời mời lần lượt từng người, và người nhận đầu tiên đi tới chỗ khách. Khách theo dõi người đó trên bản đồ như gọi xe.

Luồng hiện có (tìm người → xem hồ sơ → đặt lịch S05–S07) giữ nguyên. "Chụp ngay" là luồng thứ hai, dùng chung tài khoản, số điện thoại, escrow, chat, liên hệ, đánh giá.

**Chốt với người dùng (2026-10-01):**

| Quyết định | Lựa chọn |
|---|---|
| Thời điểm | Ngay bây giờ, trong 30–90 phút |
| Phân việc | Gửi lần lượt từng người, mỗi lời mời có hạn 30 giây |
| Giá | Nền tảng đặt giá theo gói cố định (30 phút, 1 giờ, 2 giờ), có hệ số cao điểm theo thành phố |
| Thanh toán | Khách trả đủ khi gửi yêu cầu; tiền giữ escrow; không tìm được người thì hoàn 100% tự động |
| Theo dõi | Bản đồ trực tiếp và ETA trong lúc nhiếp ảnh gia đang đến |
| Ai được nhận | Hai vòng: vòng ưu tiên (đạt chuẩn, đã chấp nhận bảng giá gói, bật "Sẵn sàng hỗ trợ"); vòng mở rộng khi khách tick "Mở rộng tìm kiếm" (mọi nhiếp ảnh gia đã hoàn tất hồ sơ ở gần) |
| Huỷ | Theo mốc thời gian (mục 4) |
| Quy mô | Nhiều thành phố ngay từ đầu |
| Kiến trúc | Dịch vụ điều phối riêng (`services/dispatch`), Redis GEO + PostgreSQL + hàng đợi hẹn giờ |
| Bản đồ | Goong (tile tương thích Mapbox, dùng `maplibre_gl` trong Flutter); dự phòng Google Maps |

**Ngoài phạm vi:** ghép một yêu cầu với nhiều nhiếp ảnh gia cùng lúc (ekip), đặt trước cho ngày khác bằng bộ ghép cặp (vẫn dùng luồng đặt lịch thường), trả giá, tip, chụp ở ngoài khu vực phục vụ của thành phố đã mở.

## 2. Luồng

### 2.1 Khách

1. Bấm **"Chụp ngay"** ở Trang chủ (S01, thẻ nổi đầu trang) hoặc tab giữa của khách (S04, nút phía trên danh sách).
2. **S47**: chọn gói, kiểu chụp (chân dung, cặp đôi, gia đình, sự kiện nhỏ, sản phẩm), ghim điểm hẹn trên bản đồ (mặc định là vị trí hiện tại; sửa được bằng kéo ghim hoặc tìm địa chỉ Goong Autocomplete), ghi chú ngắn (≤ 140 ký tự), ô **"Mở rộng tìm kiếm"** (tắt sẵn). Màn hiện giá chắc chắn và ước lượng "Thường có người nhận trong khoảng {n} phút" (trung vị 7 ngày gần nhất ở khu vực đó; chưa đủ dữ liệu thì ẩn).
3. Thiếu số điện thoại → S33 trước (spec chính 3b.1), quay lại S47.
4. Bấm **"Thanh toán {giá} và tìm"** → cổng MoMo/VNPay (dùng chung luồng thanh toán của bước 4; trước khi bước 4 xong dùng cổng giả như kế hoạch sự kiện). Trả xong → **S48** "Đang tìm".
5. Có người nhận → **S49**: bản đồ với điểm của nhiếp ảnh gia, ETA, thẻ nhiếp ảnh gia, nút Nhắn tin và `ContactDial` (đã mở khoá liên hệ, spec chính 3b.1).
6. Nhiếp ảnh gia báo đã đến → S49 đổi sang "Đã đến"; bắt đầu chụp → **S50** (đồng hồ buổi chụp). Hết giờ gói hoặc nhiếp ảnh gia bấm "Hoàn thành" → khách xác nhận (hoặc tự xác nhận sau 2 giờ) → S12 Đánh giá.
7. Không ai nhận → **S51**: đã hoàn 100%, gợi ý "Thử lại" (mở lại S47 với lựa chọn cũ và gợi ý tick "Mở rộng") hoặc "Đặt lịch thường" (S04).
8. Huỷ ở bất kỳ bước nào → **S55** (sheet) hiện số tiền hoàn hoặc phí trước khi xác nhận.

### 2.2 Nhiếp ảnh gia

1. **S52** (từ tab Công việc S19, thẻ đầu trang): đọc và chấp nhận **bảng giá gói** (lưu phiên bản đã chấp nhận), bật **"Sẵn sàng chụp ngay"**, tuỳ chọn bật **"Sẵn sàng hỗ trợ"**. Chỉ bật được khi: hoàn tất hồ sơ (S24, S34), có số điện thoại, đã chấp nhận bảng giá phiên bản hiện hành, đang ở trong một thành phố đã mở, đã cấp quyền vị trí.
2. Có lời mời → **S53**: toàn màn (kể cả khi app ở nền: thông báo ưu tiên cao kèm âm thanh), hiện gói, kiểu chụp, khoảng cách và thời gian đi, thu nhập của nhiếp ảnh gia, **điểm hẹn ở mức khu phố** (chưa có địa chỉ chính xác), ghi chú, đồng hồ đếm ngược 30 giây. "Nhận" hoặc "Từ chối" (lý do tuỳ chọn).
3. Nhận thành công → **S54**: địa chỉ chính xác, nút "Chỉ đường" (mở Goong/Google Maps/Apple Maps bên ngoài), các nút chuyển trạng thái **"Đã đến"** (chỉ bật khi cách điểm hẹn ≤ 200 m, hoặc sau xác nhận nếu GPS kém) → **"Bắt đầu chụp"** → **"Hoàn thành"**. Nhắn tin và liên hệ với khách.
4. Đang có yêu cầu thì không nhận lời mời khác. Sau khi hoàn thành, trạng thái sẵn sàng trở lại như trước.

## 3. Trạng thái và vòng mời

### 3.1 Máy trạng thái của yêu cầu (`InstantRequestStatus`)

```
pending_payment ──paid──▶ searching ──accept──▶ assigned ──start_route──▶ en_route ──arrive──▶ arrived ──start──▶ in_progress ──finish──▶ completed
        │                    │  ▲                   │                        │                    │
        │                    │  └──photographer_cancel (loại người đó, tìm lại)┘                    │
        ▼                    ▼                                                                     ▼
 payment_failed          no_match                  cancelled_by_customer (mọi bước trước in_progress)   no_show_customer
                                                    disputed (từ completed trong 24 giờ)
```

- `assigned` chuyển ngay sang `en_route` khi app nhiếp ảnh gia bắt đầu gửi vị trí (thường trong vài giây); tách hai trạng thái để biết người nhận đã thật sự lên đường.
- `completed` được đặt khi khách xác nhận hoặc tự động 2 giờ sau "Hoàn thành" của nhiếp ảnh gia. Escrow thả tiền theo spec chính 3g (cửa sổ khiếu nại).
- Mỗi chuyển đổi chỉ do dịch vụ thực hiện (client gọi API, không ghi trạng thái).

### 3.2 Vòng mời

| Tham số | Giá trị v1 (để trong cấu hình theo thành phố) |
|---|---|
| Hạn một lời mời | 30 giây |
| Vòng 1 (ưu tiên) | tối đa 5 phút; bán kính tăng 3 → 6 → 10 km mỗi khi hết người trong bán kính hiện tại |
| Vòng 2 (mở rộng, chỉ khi khách tick) | thêm tối đa 5 phút, bán kính 10 km |
| Tổng thời gian tìm | 10 phút, quá thì `no_match` và hoàn 100% |
| Lời mời đồng thời cho một nhiếp ảnh gia | 1 |
| Người đã từ chối/hết hạn với yêu cầu này | không mời lại |

- **Nhóm ưu tiên (vòng 1)**: nhiếp ảnh gia đang sẵn sàng, đã chấp nhận bảng giá hiện hành, và thoả **một** trong: đạt chuẩn (đã xác minh, đánh giá ≥ 4,5 với ≥ 5 đánh giá, tỉ lệ huỷ chụp ngay ≤ 10% khi có ≥ 10 yêu cầu; chưa đủ dữ liệu thì chỉ cần đã xác minh), hoặc bật "Sẵn sàng hỗ trợ".
- **Nhóm mở rộng (vòng 2)**: mọi nhiếp ảnh gia đang sẵn sàng đã hoàn tất hồ sơ và chấp nhận bảng giá.
- **Thứ tự mời** trong một vòng: điểm `score = 0,45·eta + 0,25·genreMatch + 0,15·rating + 0,15·reliability` (mỗi thành phần chuẩn hoá về 0..1; `eta` càng nhỏ điểm càng cao; `genreMatch` từ kỹ năng S38 với kiểu chụp đã chọn; `reliability` từ tỉ lệ nhận và huỷ). Người bật "Sẵn sàng hỗ trợ" được cộng 0,05 trong vòng 1. Module chấm điểm dùng chung với `recommender-core` (spec chính 3e) và trả về lý do để ghi nhật ký.
- **ETA khi chấm điểm**: khoảng cách đường chim bay × 1,4 chia vận tốc 20 km/h (không gọi API bản đồ cho mỗi ứng viên); ETA thật lấy từ Goong Distance Matrix chỉ cho người đã nhận.

## 4. Giá, thanh toán, huỷ

- **Gói** (`instant_packages`): mã, thời lượng phút, số ảnh chỉnh sửa giao, giá VND (số nguyên), phiên bản bảng giá. Giá cuối = giá gói × hệ số cao điểm của thành phố tại thời điểm gửi, làm tròn tới 1.000 ₫, **khoá lại trong yêu cầu** (không đổi khi đang tìm).
- **Phân chia**: nhiếp ảnh gia nhận `payoutRate` (cấu hình, đề xuất 80%) của giá; phần còn lại là phí nền tảng. Bảng giá hiện cả giá khách trả và thu nhập nhiếp ảnh gia.
- **Thu tiền**: trả đủ khi gửi. Yêu cầu chỉ chuyển `searching` khi cổng xác nhận đã trả (webhook, không tin redirect).
- **Huỷ và không đến** (khách luôn thấy số tiền ở S55 trước khi xác nhận):

| Tình huống | Khách được hoàn | Nhiếp ảnh gia nhận |
|---|---|---|
| Khách huỷ khi `searching`, hoặc trong 2 phút sau `assigned` | 100% | 0 |
| Khách huỷ khi đang đến (sau 2 phút) | 80% | 20% giá gói (phí đi lại) |
| Nhiếp ảnh gia đã đến, chờ 15 phút khách không có mặt (`no_show_customer`) | 50% | 50% |
| Nhiếp ảnh gia huỷ hoặc không đến (trễ quá 15 phút so với ETA ban đầu, khách huỷ) | 100% | 0, bị trừ điểm tin cậy |
| `no_match` | 100% | — |

- Tổng hoàn + tiền nhiếp ảnh gia + phí nền tảng luôn bằng số tiền đã thu, kiểm bằng test (không lệch 1 ₫).
- Ghi vào sổ cái `ledger_entries` như spec chính 3g; tiền nhiếp ảnh gia vào trạng thái "Đang giữ" ở S43 cho tới khi thả.

## 5. Kiến trúc

```
App Flutter ──HTTPS + Firebase ID token──▶ dispatch-service (TypeScript)
   ▲  ▲                                                                            │
   │  └── FCM data message: lời mời, đã có người nhận, đổi trạng thái              ├── Redis: GEO vị trí đang sẵn sàng, khoá lời mời, hàng đợi hẹn giờ (BullMQ)
   │                                                                               ├── PostgreSQL + PostGIS: yêu cầu, lời mời, cài đặt, độ tin cậy, sổ cái
   └── Firestore (bản sao chỉ đọc cho realtime) ◀──────────────────────────────────┘
        instant_requests/{id}          trạng thái + thông tin hiển thị (2 bên đọc)
        instant_tracks/{id}            vị trí hiện tại của nhiếp ảnh gia khi đang đến (2 bên đọc, ghi đè 1 tài liệu)
        instant_offers/{photographerId} lời mời đang chờ của người đó (chỉ người đó đọc)
```

- **Thư mục**: `services/dispatch/` (cạnh `services/recommender/`, `services/api/` của backend giai đoạn 2). Hợp đồng [`services/dispatch/api/openapi.yaml`](../../../services/dispatch/api/openapi.yaml), phiên bản `/v1`, gồm cả dạng bản sao Firestore (`*Mirror`). Domain thuần ở `packages/dispatch-core` (cạnh `packages/domain` của backend giai đoạn 1).
- **Gọi dịch vụ**: ứng dụng gọi thẳng HTTPS kèm Firebase ID token (cùng cách kiểm token với backend giai đoạn 2), không qua callable, để chỉ có một adapter từ đầu.
- **Module**:
  - `domain/` (TypeScript thuần, không import hạ tầng): máy trạng thái, luật vòng mời, chấm điểm, tính tiền và huỷ. Dùng chung chấm điểm với `recommender-core`.
  - `presence`: bật/tắt sẵn sàng, cập nhật vị trí → `GEOADD online:{cityId}` + `presence:{uid}` TTL 10 phút. Hết TTL coi như ngoại tuyến.
  - `matcher`: `GEOSEARCH` theo bán kính, lọc vòng/đã từ chối/đang bận, chấm điểm, giữ chỗ người đứng đầu bằng `SET offerlock:{uid} NX PX 30000`.
  - `offers`: tạo lời mời, gửi FCM, ghi `instant_offers/{uid}`, đặt việc hẹn giờ 30 giây; "Nhận" là một giao dịch PostgreSQL thành công chỉ khi lời mời còn hạn và yêu cầu còn `searching` (khoá dòng `SELECT … FOR UPDATE`).
  - `tracking`: nhận vị trí khi `en_route`, ghi đè `instant_tracks/{id}`, tính ETA bằng Goong Distance Matrix tối đa 1 lần mỗi phút, dừng khi `arrived`.
  - `payments`: giữ, hoàn, chia tiền qua sổ cái chung.
  - `api`: các thao tác ở mục 6.
- **Triển khai**: Cloud Run (hoặc container trong Docker Compose của backend giai đoạn 2 khi chạy local), Redis có lưu bền (Memorystore hoặc container), PostgreSQL dùng chung cơ sở dữ liệu của backend giai đoạn 2 (schema `dispatch`).
- **Vì sao không chỉ Firestore**: nhiều thành phố từ đầu; vị trí cập nhật liên tục (ghi Firestore tính tiền từng lần); cần khoá chống mời trùng và hẹn giờ chính xác. Firestore chỉ còn là kênh realtime cho app ở giai đoạn đầu, để không phải thêm WebSocket ngay.

## 6. API (tóm tắt; hợp đồng đầy đủ ở `services/dispatch/api/openapi.yaml`)

| Thao tác | Ai gọi | Ghi chú |
|---|---|---|
| `GET /v1/packages?cityId=` | cả hai | gói, giá hiện tại (đã nhân hệ số), phiên bản bảng giá, ước lượng thời gian có người nhận |
| `POST /v1/requests` | khách | `{packageId, genre, meetPoint{lat,lng,address}, note, expand}` → `{requestId, amount, paymentUrl}`; lỗi `phone_required`, `outside_service_area`, `price_changed` |
| `POST /v1/requests/{id}/cancel` | khách / nhiếp ảnh gia | trả `{refund, fee}` đã tính; khách gọi trước với `dryRun: true` để hiện ở S55 |
| `POST /v1/requests/{id}/confirm-complete` | khách | |
| `PUT /v1/presence` | nhiếp ảnh gia | `{online, helpReady, location{lat,lng,accuracy}}`; lỗi `not_eligible{reasons[]}` |
| `POST /v1/offers/{id}/accept` · `/decline` | nhiếp ảnh gia | lỗi `offer_expired`, `already_assigned` |
| `POST /v1/requests/{id}/location` | nhiếp ảnh gia (đang đến) | `{lat,lng,accuracy,heading,speed}`; giới hạn 1 lần / 5 giây |
| `POST /v1/requests/{id}/arrive` · `/start` · `/finish` | nhiếp ảnh gia | `arrive` kiểm khoảng cách ≤ 200 m hoặc `force: true` có ghi nhật ký |
| `PUT /v1/instant-settings` | nhiếp ảnh gia | chấp nhận bảng giá `{priceListVersion}`, `helpReady` |

Mã lỗi mới thêm vào `ErrorCode` (`data-model/domain-model.md`): `no_match`, `offer_expired`, `already_assigned`, `not_eligible`, `outside_service_area`, `price_changed`.

## 7. Dữ liệu

Thêm vào `data-model/relational-schema.md` (schema `dispatch`); id ULID, thời gian UTC, tiền VND số nguyên, enum là chuỗi:

| Bảng | Cột chính |
|---|---|
| `cities` | `id`, `name`, `boundary geography(Polygon)`, `surge numeric(3,2)`, `active` |
| `instant_packages` | `id`, `code`, `duration_min`, `photos`, `price_vnd`, `price_list_version`, `active` |
| `instant_requests` | `id`, `customer_id`, `package_id`, `city_id`, `genre`, `meet_point geography(Point)`, `meet_address`, `note`, `expand`, `amount_vnd`, `payout_vnd`, `status`, `photographer_id?`, `round`, `requested_at`, `assigned_at?`, `arrived_at?`, `started_at?`, `finished_at?`, `completed_at?`, `cancelled_at?`, `cancel_reason?`, `version` |
| `instant_offers` | `id`, `request_id`, `photographer_id`, `round`, `score`, `reasons jsonb`, `offered_at`, `expires_at`, `outcome (pending\|accepted\|declined\|expired\|withdrawn)`, `decided_at?` |
| `photographer_instant_settings` | `photographer_id` PK, `price_list_version_accepted`, `help_ready`, `home_city_id`, `updated_at` |
| `photographer_reliability` | `photographer_id` PK, `offers`, `accepted`, `cancelled`, `no_show`, `updated_at` |

Chỉ mục: `instant_requests(status, city_id)`, `instant_offers(request_id)`, `instant_offers(photographer_id, outcome)`, GiST trên `meet_point` và `cities.boundary`. Vị trí sẵn sàng **không** lưu ở PostgreSQL (chỉ Redis, có TTL). Vị trí khi đang đến chỉ giữ điểm mới nhất; khi yêu cầu kết thúc, xoá `instant_tracks/{id}` và không lưu lịch sử điểm.

Firestore (bản sao, chỉ dịch vụ ghi): `instant_requests/{id}` (`status`, `customerId`, `photographerId`, tóm tắt nhiếp ảnh gia, `etaMinutes`, `meetPoint` chỉ khi đã `assigned`, `updatedAt`), `instant_tracks/{id}`, `instant_offers/{photographerId}`. Rules: client không ghi; `instant_requests` và `instant_tracks` chỉ khách và nhiếp ảnh gia của yêu cầu đọc; `instant_offers/{uid}` chỉ chủ đọc.

## 8. Màn hình mới (S47–S55)

| Mã | Màn | Route | Vai trò |
|----|-----|-------|---------|
| S47 | Chụp ngay: gói, kiểu chụp, điểm hẹn, "Mở rộng tìm kiếm", giá | `/instant` | khách |
| S48 | Đang tìm nhiếp ảnh gia | `/instant/:id` (status `searching`) | khách |
| S49 | Đã có người nhận / đang đến (bản đồ, ETA) | `/instant/:id` (`assigned`, `en_route`, `arrived`) | khách |
| S50 | Đang chụp / chờ xác nhận hoàn thành | `/instant/:id` (`in_progress`, chờ xác nhận) | khách |
| S51 | Không tìm được người | `/instant/:id` (`no_match`) | khách |
| S52 | Sẵn sàng chụp ngay (công tắc, bảng giá, "Sẵn sàng hỗ trợ") | `/work/instant` | NAG |
| S53 | Lời mời việc (toàn màn, đếm ngược) | `/work/instant/offer/:offerId` | NAG |
| S54 | Đang đến / đã đến / đang chụp | `/work/instant/:id` | NAG |
| S55 | Huỷ chụp ngay (sheet) | `/instant/:id/cancel` | cả hai |

Một route `/instant/:id` hiển thị S48–S51 theo trạng thái nghe từ Firestore; mỗi trạng thái bọc `ScreenCode` riêng. Bảng mã ở spec chính mục 2, `ScreenCodes` và mock được cập nhật cùng lúc.

**Chuỗi chính** (khoá ARB đặt khi viết plan): "Chụp ngay", "Nhiếp ảnh gia tới chỗ bạn trong khoảng 30–90 phút", "Mở rộng tìm kiếm", "Tìm cả nhiếp ảnh gia khác ở gần nếu chưa có người nhận", "Thanh toán {giá} và tìm", "Tiền được giữ an toàn và hoàn 100% nếu không có người nhận.", "Đang tìm nhiếp ảnh gia gần bạn", "{tên} đã nhận · đến trong khoảng {n} phút", "Đã đến điểm hẹn", "Chưa tìm được nhiếp ảnh gia. Đã hoàn {số tiền}.", "Sẵn sàng chụp ngay", "Sẵn sàng hỗ trợ", "Nhận việc trong {n} giây", "Đang nhận việc chụp ngay" (thông báo bền Android).

**Quy ước UI** (theo spec chính và `shared-components.md`): một nút chính mỗi màn; nút Huỷ là chữ đỏ mở S55, xác nhận huỷ là nút đỏ trong sheet; số tiền hoàn luôn hiện bằng chữ trước khi xác nhận; S53 có vùng chạm lớn (Nhận ≥ 56dp), đếm ngược bằng số và vòng, không chỉ bằng màu; bản đồ có nút "Về vị trí của tôi" và nhãn chữ cho mọi ghim; giảm chuyển động thì tắt hiệu ứng sóng ở S48 và trượt ghim ở S49.

## 9. Vị trí, pin và riêng tư

| Trạng thái | Nguồn vị trí | Tần suất | Độ chính xác |
|---|---|---|---|
| Nhiếp ảnh gia sẵn sàng, không có việc | dịch vụ vị trí khi di chuyển | khi đi > 300 m hoặc 5 phút một lần | thấp (~100 m) |
| Đang đến | luồng vị trí | 10–15 giây | cao |
| Đã đến / đang chụp / tắt sẵn sàng | — | dừng | — |
| Khách | một lần ở S47 (spec chính 3c) | một lần | trung bình |

- **Android**: khi sẵn sàng hoặc đang đến, chạy foreground service loại `location` với thông báo bền "Đang nhận việc chụp ngay" (bắt buộc từ Android 14, `FOREGROUND_SERVICE_LOCATION`); xin `ACCESS_FINE_LOCATION` khi dùng app; **không** xin `ACCESS_BACKGROUND_LOCATION` (foreground service đủ cho việc đang mở). Thông báo có nút "Tắt".
- **iOS**: quyền "Khi dùng app"; khi sẵn sàng/đang đến bật `allowsBackgroundLocationUpdates` với `showsBackgroundLocationIndicator = true` (chấm xanh trên thanh trạng thái), `UIBackgroundModes` gồm `location`. Đây là ngoại lệ có chủ đích so với kế hoạch bật iOS (vốn cấm `UIBackgroundModes`); kế hoạch của Chụp ngay cập nhật test đó. Không bao giờ xin "Luôn luôn".
- **Tự tắt**: 30 phút sẵn sàng mà không mở app → thông báo "Vẫn muốn nhận việc?"; không trả lời trong 5 phút → tự tắt. Pin dưới 15% → nhắc và đề nghị tắt.
- **Bản đồ** chỉ vẽ khi S49/S54 đang mở; tile cache của `maplibre_gl`; ghim di chuyển nội suy giữa hai điểm (không vẽ lại cả bản đồ).
- **Riêng tư**: địa chỉ chính xác chỉ gửi cho người đã nhận; trước đó lời mời chỉ có khu phố và khoảng cách. Vị trí nhiếp ảnh gia chỉ khách của yêu cầu thấy, chỉ khi đang đến. Không lưu lịch sử điểm. Số điện thoại vẫn theo luật mở khoá liên hệ (spec chính 3b).
- **Ngưỡng pin** (thêm vào `docs/testing/battery-and-performance.md`): sẵn sàng 1 giờ ≤ 3% pin; đang đến 30 phút ≤ 6%; GPS tắt hẳn trong 10 giây sau "Đã đến" hoặc tắt sẵn sàng.

## 10. Lỗi và tình huống biên

| Tình huống | Xử lý |
|---|---|
| Thanh toán lỗi hoặc huỷ ở cổng | Yêu cầu ở `payment_failed`, không tìm; S47 giữ lựa chọn để thử lại |
| Khách mất mạng khi đang tìm | Dịch vụ vẫn tìm; app nghe lại Firestore khi có mạng; quá 10 phút thì thấy S51 |
| Hai nhiếp ảnh gia cùng bấm Nhận | Khoá Redis + giao dịch PostgreSQL cho một người thắng; người kia thấy "Yêu cầu đã có người nhận" (`already_assigned`) |
| Lời mời hết hạn đúng lúc bấm Nhận | Dịch vụ là trọng tài theo thời gian server; quá hạn trả `offer_expired` |
| FCM trễ hoặc mất | Lời mời vẫn hết hạn sau 30 giây; app nhiếp ảnh gia đang sẵn sàng nghe `instant_offers/{uid}` nên vẫn thấy nếu đang mở |
| Nhiếp ảnh gia mất tín hiệu khi đang đến | Quá 3 phút không có vị trí: khách thấy "Đang chờ cập nhật vị trí"; trễ quá 15 phút so với ETA ban đầu: khách huỷ được với hoàn 100% |
| Goong lỗi hoặc hết hạn mức | ETA ước tính (đường chim bay × 1,4, 20 km/h) và ghi "ước tính"; bản đồ hiện lỗi tải tile nhưng vẫn có ETA và nút liên hệ |
| Khách ở ngoài thành phố đã mở | `outside_service_area`; S47 báo và gợi ý đặt lịch thường |
| Giá đổi giữa lúc xem và lúc trả | `price_changed`; S47 hiện giá mới và hỏi lại |
| Nhiếp ảnh gia bấm "Đã đến" khi còn xa | Từ chối nếu > 200 m; cho xác nhận với lý do nếu độ chính xác GPS kém (> 100 m), ghi nhật ký |
| Khách không xác nhận hoàn thành | Tự hoàn thành 2 giờ sau "Hoàn thành" của nhiếp ảnh gia; khiếu nại trong 24 giờ → `disputed` |
| Dịch vụ điều phối sập | Nút "Chụp ngay" ẩn (cờ cấu hình từ `GET /v1/packages` lỗi); yêu cầu đang dở tiếp tục khi dịch vụ lên lại nhờ trạng thái trong PostgreSQL và việc hẹn giờ lưu bền trong Redis |

## 11. Kiểm thử

- **Domain (unit, không hạ tầng)**: mọi chuyển trạng thái hợp lệ và bị từ chối; vòng mời (bán kính tăng, chuyển vòng 2 chỉ khi `expand`, tổng 10 phút); chấm điểm và lý do; mọi dòng bảng huỷ mục 4, tổng tiền không lệch 1 ₫; làm tròn giá với hệ số.
- **Dịch vụ (Redis + PostgreSQL thật, Docker Compose của backend giai đoạn 2)**: 50 yêu cầu đồng thời không mời trùng một người; hai người cùng nhận chỉ một thắng; hết 30 giây chuyển người kế; hết 10 phút `no_match` và bút toán hoàn; TTL vị trí làm người đó bị loại; dịch vụ khởi động lại giữa chừng vẫn tiếp tục yêu cầu đang tìm.
- **Tải**: script sinh 2.000 nhiếp ảnh gia ở 3 thành phố và 100 yêu cầu/phút trong 10 phút. Ngưỡng: thời gian tới lời mời đầu tiên p95 < 2 giây; `matcher` p95 < 50 ms; không lời mời trùng.
- **App (widget)**: S47–S55 ở 320dp, chữ 1,3×, sáng và tối, `expectIdle` (S48 có hiệu ứng sóng: test với giảm chuyển động bật thì idle; tắt thì chỉ chạy khi đang tìm và dừng khi đổi trạng thái); đếm ngược S53 đúng giây; S55 hiện đúng số tiền từ `dryRun`.
- **App (integration, bản giả)**: luồng đầy đủ khách + nhiếp ảnh gia trên hai `ProviderScope`; không có người nhận; nhiếp ảnh gia huỷ rồi tìm lại; khách huỷ ở từng mốc.
- **Rules**: client không ghi `instant_*`; người ngoài không đọc được `instant_requests`/`instant_tracks`; `instant_offers/{uid}` chỉ chủ đọc.
- **Pin (tay, máy thật)**: theo hướng dẫn kiểm tra pin với ba kịch bản: sẵn sàng 1 giờ không có việc; một chuyến đang đến 30 phút; bật rồi tắt sẵn sàng (GPS tắt trong 10 giây). Android và iOS.

## 12. Kế hoạch triển khai (thứ tự)

| # | Kế hoạch | Phụ thuộc |
|---|---|---|
| I1 | Spec này, mock S47–S55, bảng mã, `ErrorCode`, schema | — |
| I2 | `services/dispatch` domain (TypeScript thuần) và test | backend giai đoạn 1 (cấu trúc TypeScript) |
| I3 | Dịch vụ điều phối: presence, matcher, offers, tracking, payments (giả), API, FCM, bản sao Firestore, test đồng thời và tải | I2, backend giai đoạn 2 (Docker Compose, PostgreSQL) |
| I4 | App nhiếp ảnh gia: S52–S54, `PresenceRepository`, foreground service, tracking | I3, kế hoạch 2b (liên hệ), 2d (hồ sơ) |
| I5 | App khách: S47–S51, S55, bản đồ Goong, `InstantBookingRepository` | I3, kế hoạch 2a (số điện thoại), 3a (vị trí) |
| I6 | Thanh toán thật và escrow cho chụp ngay | bước 4 (thanh toán), spec chính 3g |

Mỗi kế hoạch kết thúc bằng task kiểm tra pin và hiệu năng như các kế hoạch khác.

## 13. Câu hỏi mở

1. Bảng giá v1 (giá từng gói theo thành phố, `payoutRate` 80%, hệ số cao điểm và khung giờ) cần chủ sản phẩm chốt.
2. Danh sách thành phố mở đầu tiên và ranh giới (polygon).
3. Có bắt nhiếp ảnh gia đặt cọc/ký cam kết riêng cho chụp ngay không (để giảm bỏ việc)?
4. Khoá API Goong (Maps, Autocomplete, Distance Matrix): tài khoản, hạn mức, và cách cấp khoá cho app (khoá giới hạn theo bundle/package).
5. Pháp lý: lưu vị trí thời gian thực của nhiếp ảnh gia (đồng ý rõ ràng ở S52, chính sách quyền riêng tư).
6. Chính sách khi khách báo nhiếp ảnh gia không đúng người trong hồ sơ (đối chiếu ảnh đại diện ở S49, nút báo cáo).
