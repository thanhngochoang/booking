# Chụp ngay: đặt nhiếp ảnh gia tức thì, khách chọn kiểu "match"

Ngày 2026-10-01, sửa ngày 2026-10-02. Bổ sung cho spec chính [`2026-10-01-remaining-screens.md`](2026-10-01-remaining-screens.md) (gọi là "spec chính"). Mục 3e.4 của spec chính ghi "ghép cặp tự động là sản phẩm khác, ngoài phạm vi v1"; spec này chính là sản phẩm đó và thay cho ghi chú ấy.

**Sửa ngày 2026-10-02 (người dùng):** chưa tìm được người thì không tự hoàn tiền; tiền treo tới khi khách huỷ hẳn yêu cầu.

**Sửa ngày 2026-10-02 (người dùng, trước đó):** bỏ cách "gửi lần lượt từng người, khách không chọn" kiểu Uber. Thay bằng cách gần app hẹn hò: hệ thống giới thiệu 5 nhiếp ảnh gia phù hợp nhất, khách vuốt chọn một hoặc nhiều người trong 5 người đó, lời mời gửi **cùng lúc** cho những người được chọn, **ai nhận trước thì được** ("match"). Không ai nhận thì khách vuốt 5 người tiếp theo.

## 1. Mục tiêu và phạm vi

Khách cần nhiếp ảnh gia **ngay bây giờ** (buổi chụp bắt đầu trong 30–90 phút) ở chỗ mình đang đứng. Hệ thống gợi ý 5 nhiếp ảnh gia phù hợp ở gần; khách chọn người mình thích; lời mời đi tới những người đó cùng lúc; người nhận đầu tiên đi tới chỗ khách và khách theo dõi trên bản đồ như gọi xe.

Luồng hiện có (tìm người → xem hồ sơ → đặt lịch S04.01–S04.03) giữ nguyên. "Chụp ngay" là luồng thứ hai, dùng chung tài khoản, số điện thoại, escrow, chat, liên hệ, đánh giá.

**Chốt với người dùng (2026-10-01, sửa 2026-10-02):**

| Quyết định | Lựa chọn |
|---|---|
| Thời điểm | Ngay bây giờ, trong 30–90 phút |
| Phân việc | Hệ thống gợi ý **5 người** phù hợp nhất; khách **vuốt chọn 1–5 người**; lời mời gửi **cùng lúc** cho người được chọn; **ai nhận trước thì được**. Không ai nhận thì khách chọn tiếp trong **5 người kế tiếp** |
| Hạn một lời mời | 60 giây (trước là 30 giây; không còn chờ lần lượt) |
| Giao diện chọn | Thẻ vuốt kiểu hẹn hò (♥ chọn, ✕ bỏ qua, có nút thay cho cử chỉ) |
| Giá | Nền tảng đặt giá theo gói cố định (30 phút, 1 giờ, 2 giờ), có hệ số cao điểm theo thành phố; mọi người trong danh sách cùng một giá |
| Thanh toán | Xem và chọn miễn phí; trả đủ khi gửi lời mời lần đầu; tiền giữ escrow; các lượt sau dùng khoản đã giữ; chưa tìm được người thì **không tự hoàn**: tiền vẫn treo cho tới khi có người nhận hoặc khách huỷ hẳn yêu cầu (huỷ khi chưa có người nhận → hoàn 100%) |
| Tên tính năng phía nhiếp ảnh gia | **Live Shutter**: công tắc bật sẵn sàng nhận lời mời chụp ngay (S14.01). Giữ nguyên tên tiếng Anh trong giao diện |
| Theo dõi | Bản đồ trực tiếp và ETA trong lúc nhiếp ảnh gia đang đến |
| Ai được gợi ý | Nhóm ưu tiên trước (đạt chuẩn, đã chấp nhận bảng giá gói, bật "Sẵn sàng hỗ trợ"), nhóm mở rộng chỉ khi nhóm ưu tiên không đủ 5 người. Bỏ ô "Mở rộng tìm kiếm" của khách |
| Huỷ | Theo mốc thời gian (mục 4) |
| Quy mô | Nhiều thành phố ngay từ đầu |
| Kiến trúc | Dịch vụ điều phối riêng (`services/dispatch`), Redis GEO + PostgreSQL + hàng đợi hẹn giờ |
| Bản đồ | Goong (tile tương thích Mapbox, dùng `maplibre_gl` trong Flutter); dự phòng Google Maps |

**Ngoài phạm vi:** ghép một yêu cầu với nhiều nhiếp ảnh gia cùng lúc (ekip), đặt trước cho ngày khác bằng bộ ghép cặp (vẫn dùng luồng đặt lịch thường), trả giá, tip, chụp ở ngoài khu vực phục vụ của thành phố đã mở, xem hồ sơ đầy đủ S03.01 từ thẻ vuốt (v1 chỉ có thẻ; chạm ảnh xem lớn hơn).

## 2. Luồng

### 2.1 Khách

1. Bấm **"Chụp ngay"** ở Trang chủ (S02.01, thẻ nổi đầu trang) hoặc tab giữa của khách (S02.06, nút phía trên danh sách).
2. **S13.01**: chọn gói, kiểu chụp (chân dung, cặp đôi, gia đình, sự kiện nhỏ, sản phẩm), ghim điểm hẹn trên bản đồ (mặc định là vị trí hiện tại; sửa được bằng kéo ghim hoặc tìm địa chỉ Goong Autocomplete), ghi chú ngắn (≤ 140 ký tự). Màn hiện giá chắc chắn và ước lượng "Thường có người nhận trong khoảng {n} phút" (trung vị 7 ngày gần nhất ở khu vực đó; chưa đủ dữ liệu thì ẩn). Nút chính **"Xem nhiếp ảnh gia phù hợp"** (chưa thu tiền).
3. Thiếu số điện thoại → S04.05 trước (spec chính 3b.1), quay lại S13.01.
4. **S13.02 · Vuốt chọn**: tối đa 5 thẻ lớn, mỗi thẻ: ảnh portfolio (vuốt ngang trong thẻ để xem 3 ảnh), tên + dấu xác minh, đánh giá, ETA ước tính, chip lý do ("Chuyên chân dung", "Cách 1,2 km"). **Vuốt phải hoặc ♥ = chọn**, **vuốt trái hoặc ✕ = bỏ qua**; nút "Hoàn tác" cho thẻ vừa vuốt. Hết thẻ (hoặc bấm "Xong") → tóm tắt những người đã chọn (bỏ chọn được) và nút chính **"Thanh toán {giá} và gửi lời mời"** (lượt đầu) hoặc **"Gửi lời mời"** (lượt sau). Không chọn ai → "Xem 5 người khác". Ít hơn 5 ứng viên thì hiện bao nhiêu có bấy nhiêu; không có ai → báo "Hiện chưa có nhiếp ảnh gia sẵn sàng gần bạn" và gợi ý "Đặt lịch thường" (S02.06), chưa thu tiền.
5. Lượt đầu: cổng MoMo/VNPay (dùng chung luồng thanh toán của bước 4; trước khi có cổng thật dùng cổng giả như kế hoạch 4b). Trả xong → lời mời gửi đi → **S13.03 · Đang chờ trả lời**: danh sách người đã mời, mỗi người một dòng trạng thái (đang xem, đã từ chối, hết hạn), đồng hồ 60 giây; người vừa bận ngay lúc gửi được báo "{tên} vừa nhận việc khác" và không tính.
6. Có người nhận → **S13.04 · Đã match** (màn chuyển tiếp ~1,5 giây: hai avatar, "Đã match với {tên}") → **S13.05**: bản đồ với điểm của nhiếp ảnh gia, ETA, thẻ nhiếp ảnh gia, nút Nhắn tin và `ContactDial` (đã mở khoá liên hệ, spec chính 3b.1). Lời mời của những người còn lại tự rút.
7. Không ai nhận (mọi lời mời từ chối/hết hạn) → yêu cầu về `choosing`, khách vuốt **5 người tiếp theo** (không gồm người đã từ chối, đã hết hạn hoặc khách đã bỏ qua) và gửi lời mời mới, không trả thêm.
8. Nhiếp ảnh gia báo đã đến → S13.05 đổi sang "Đã đến"; bắt đầu chụp → **S13.06** (đồng hồ buổi chụp). Hết giờ gói hoặc nhiếp ảnh gia bấm "Hoàn thành" → khách xác nhận (hoặc tự xác nhận sau 2 giờ) → S05.05 Đánh giá.
9. Hết 10 phút kể từ lúc trả tiền (hoặc kể từ lượt chọn gần nhất) mà chưa match, hoặc hết ứng viên trong bán kính tối đa → **S13.07** · `no_match`: **tiền vẫn treo**, không tự hoàn. Khách chọn "Chọn thêm người" (S13.02 với lượt mới, không trả thêm; danh sách có thể rỗng khi chưa ai sẵn sàng, khi đó báo và để khách thử lại sau), "Huỷ yêu cầu" (S13.08, hoàn 100%), hoặc sang "Đặt lịch thường" (S02.06; yêu cầu chụp ngay vẫn giữ tới khi khách huỷ).
10. Huỷ ở bất kỳ bước nào → **S13.08** (sheet) hiện số tiền hoàn hoặc phí trước khi xác nhận. Huỷ trước khi trả tiền thì không có tiền nào liên quan.

### 2.2 Nhiếp ảnh gia

1. **S14.01** (từ tab Công việc S06.01, thẻ đầu trang): đọc và chấp nhận **bảng giá gói** (lưu phiên bản đã chấp nhận), bật **"Live Shutter"**, tuỳ chọn bật **"Sẵn sàng hỗ trợ"**. Chỉ bật được khi: hoàn tất hồ sơ (S08.01, S08.05), có số điện thoại, đã chấp nhận bảng giá phiên bản hiện hành, đang ở trong một thành phố đã mở, đã cấp quyền vị trí.
2. Có lời mời → **S14.02**: toàn màn (kể cả khi app ở nền: thông báo ưu tiên cao kèm âm thanh), hiện gói, kiểu chụp, khoảng cách và thời gian đi, thu nhập của nhiếp ảnh gia, **điểm hẹn ở mức khu phố** (chưa có địa chỉ chính xác), ghi chú, đồng hồ đếm ngược **60 giây**, và dòng "Khách đã chọn bạn trong {n} người" (không nêu tên người khác). Có thể có **nhiều lời mời cùng lúc** (tối đa 3) từ nhiều khách: hiện thành chồng thẻ, mỗi thẻ đếm ngược riêng. "Nhận" hoặc "Từ chối" (lý do tuỳ chọn).
3. Nhận thành công → **S13.04 · Đã match** (chuyển tiếp) → **S14.03**: địa chỉ chính xác, nút "Chỉ đường" (mở Goong/Google Maps/Apple Maps bên ngoài), các nút chuyển trạng thái **"Đã đến"** (chỉ bật khi cách điểm hẹn ≤ 200 m, hoặc sau xác nhận nếu GPS kém) → **"Bắt đầu chụp"** → **"Hoàn thành"**. Nhắn tin và liên hệ với khách. Các lời mời khác của người đó tự rút.
4. Bấm Nhận nhưng khách đã match người khác trước → "Khách đã chọn được người khác" (`already_assigned`), thẻ biến mất.
5. Đang có yêu cầu thì không nhận lời mời mới (không được gợi ý cho khách khác). Sau khi hoàn thành, trạng thái sẵn sàng trở lại như trước.

## 3. Trạng thái, gợi ý và lời mời

### 3.1 Máy trạng thái của yêu cầu (`InstantRequestStatus`)

```
choosing ──invite (lượt đầu)──▶ pending_payment ──paid──▶ searching ──accept──▶ assigned ──start_route──▶ en_route ──arrive──▶ arrived ──start──▶ in_progress ──finish──▶ completed
   ▲  │                              │                      │  │                   │
   │  └─(khách bỏ, chưa trả)─▶ abandoned   payment_failed    │  └─hết lời mời─▶ choosing (lượt sau: invite ──▶ searching, không trả lại)
   │                                                         │
   └────────────── photographer_cancel (loại người đó) ───────┘                    cancelled_by_customer (mọi bước trước in_progress)
                                          no_match (hết 10 phút, hoặc hết ứng viên; tiền vẫn treo) ──chọn lại──▶ choosing · ──huỷ──▶ cancelled_by_customer (hoàn 100%)        no_show_customer · disputed
```

- Yêu cầu tạo ra ở `choosing` (chưa có tiền); bỏ dở quá 30 phút không gửi lời mời → `abandoned` (không có tiền nào liên quan).
- `searching` = đang có ít nhất một lời mời chờ trả lời. Khi lời mời cuối cùng của lượt hết hạn hoặc bị từ chối mà chưa ai nhận → về `choosing`.
- `assigned` chuyển ngay sang `en_route` khi app nhiếp ảnh gia bắt đầu gửi vị trí; tách hai trạng thái để biết người nhận đã thật sự lên đường.
- Nhiếp ảnh gia huỷ sau khi nhận → yêu cầu về `choosing` (người đó bị loại), khách chọn lại không trả thêm; mốc 10 phút tính lại từ lúc huỷ.
- `no_match` **không phải trạng thái kết thúc**: tiền vẫn `held`, không có bút toán hoàn. Từ `no_match` khách chọn lại (→ `choosing`, mốc 10 phút tính lại khi gửi lời mời mới) hoặc huỷ (→ `cancelled_by_customer`, hoàn 100%). Hệ thống không bao giờ tự hoàn khi chưa tìm được người.
- `completed` được đặt khi khách xác nhận hoặc tự động 2 giờ sau "Hoàn thành" của nhiếp ảnh gia. Escrow thả tiền theo spec chính 3g.
- Mỗi chuyển đổi chỉ do dịch vụ thực hiện (client gọi API, không ghi trạng thái).

### 3.2 Gợi ý (lượt 5 người)

| Tham số | Giá trị v1 (để trong cấu hình theo thành phố) |
|---|---|
| Số ứng viên mỗi lượt | 5 |
| Bán kính | 3 km, nới 6 km rồi 10 km cho tới khi đủ 5 người |
| Thứ tự nhóm | Nhóm ưu tiên trước; nhóm mở rộng chỉ để lấp cho đủ 5 |
| Loại khỏi gợi ý | Đang có yêu cầu; đã có 3 lời mời đang chờ; đã từ chối hoặc để hết hạn yêu cầu này; khách đã vuốt bỏ ở lượt trước của yêu cầu này |
| Giữ chỗ khi khách đang xem | Không (kiểm lại lúc gửi lời mời) |

- **Nhóm ưu tiên**: nhiếp ảnh gia đang sẵn sàng, đã chấp nhận bảng giá hiện hành, và thoả **một** trong: đạt chuẩn (đã xác minh, đánh giá ≥ 4,5 với ≥ 5 đánh giá, tỉ lệ huỷ chụp ngay ≤ 10% khi có ≥ 10 yêu cầu; chưa đủ dữ liệu thì chỉ cần đã xác minh), hoặc bật "Sẵn sàng hỗ trợ".
- **Nhóm mở rộng**: mọi nhiếp ảnh gia đang sẵn sàng đã hoàn tất hồ sơ và chấp nhận bảng giá.
- **Điểm** trong một nhóm: `score = 0,45·eta + 0,25·genreMatch + 0,15·rating + 0,15·reliability` (mỗi thành phần chuẩn hoá về 0..1; `eta` càng nhỏ điểm càng cao; `genreMatch` từ kỹ năng S08.02 với kiểu chụp đã chọn; `reliability` từ tỉ lệ nhận và huỷ). Người bật "Sẵn sàng hỗ trợ" được cộng 0,05 trong nhóm ưu tiên. Module chấm điểm dùng chung với `recommender-core` (spec chính 3e) và trả về lý do; hai lý do đầu hiện thành chip trên thẻ.
- **ETA khi chấm điểm**: khoảng cách đường chim bay × 1,4 chia vận tốc 20 km/h (không gọi API bản đồ cho mỗi ứng viên); ETA thật lấy từ Goong Distance Matrix chỉ cho người đã nhận.

### 3.3 Lời mời

| Tham số | Giá trị v1 |
|---|---|
| Hạn một lời mời | 60 giây |
| Lời mời đang chờ tối đa cho một nhiếp ảnh gia | 3 (từ nhiều khách khác nhau) |
| Người được mời trong một lượt | 1–5, đúng những người khách chọn và vẫn còn sẵn sàng lúc gửi |
| Thời gian tìm một đợt | 10 phút kể từ lúc trả tiền hoặc lượt chọn gần nhất (tính lại khi nhiếp ảnh gia huỷ sau khi nhận); quá thì `no_match`, tiền vẫn treo cho tới khi khách chọn lại hoặc huỷ |
| Người thắng | Giao dịch "Nhận" đầu tiên thành công (khoá dòng yêu cầu `SELECT … FOR UPDATE`); mọi lời mời khác của yêu cầu và mọi lời mời khác của người thắng chuyển `withdrawn` |

## 4. Giá, thanh toán, huỷ

- **Gói** (`instant_packages`): mã, thời lượng phút, số ảnh chỉnh sửa giao, giá VND (số nguyên), phiên bản bảng giá. Giá cuối = giá gói × hệ số cao điểm của thành phố tại thời điểm gửi, làm tròn tới 1.000 ₫, **khoá lại trong yêu cầu** (không đổi khi đang tìm).
- **Phân chia**: nhiếp ảnh gia nhận `payoutRate` (cấu hình, đề xuất 80%) của giá; phần còn lại là phí nền tảng. Bảng giá hiện cả giá khách trả và thu nhập nhiếp ảnh gia.
- **Thu tiền**: khách xem và vuốt chọn miễn phí; trả đủ khi bấm "Thanh toán {giá} và gửi lời mời" ở lượt đầu. Lời mời chỉ được gửi khi cổng xác nhận đã trả (webhook, không tin redirect). Các lượt chọn lại sau đó dùng khoản đang giữ, không thu thêm.
- **Huỷ và không đến** (khách luôn thấy số tiền ở S13.08 trước khi xác nhận):

| Tình huống | Khách được hoàn | Nhiếp ảnh gia nhận |
|---|---|---|
| Khách huỷ khi `choosing` hoặc `searching`, hoặc trong 2 phút sau `assigned` | 100% | 0 |
| Khách huỷ khi đang đến (sau 2 phút) | 80% | 20% giá gói (phí đi lại) |
| Nhiếp ảnh gia đã đến, chờ 15 phút khách không có mặt (`no_show_customer`) | 50% | 50% |
| Nhiếp ảnh gia huỷ hoặc không đến (trễ quá 15 phút so với ETA ban đầu, khách huỷ) | 100% | 0, bị trừ điểm tin cậy |
| `no_match` rồi khách huỷ | 100% (chỉ khi khách huỷ; không tự hoàn) | — |

- Tổng hoàn + tiền nhiếp ảnh gia + phí nền tảng luôn bằng số tiền đã thu, kiểm bằng test (không lệch 1 ₫).
- Ghi vào sổ cái `ledger_entries` như spec chính 3g; tiền nhiếp ảnh gia vào trạng thái "Đang giữ" ở S06.05 cho tới khi thả.

## 5. Kiến trúc

```
App Flutter ──HTTPS + Firebase ID token──▶ dispatch-service (TypeScript)
   ▲  ▲                                                                            │
   │  └── FCM data message: lời mời, đã match, đổi trạng thái                      ├── Redis: GEO vị trí đang sẵn sàng, đếm lời mời đang chờ, hàng đợi hẹn giờ (BullMQ)
   │                                                                               ├── PostgreSQL + PostGIS: yêu cầu, ứng viên, lời mời, cài đặt, độ tin cậy, sổ cái
   └── Firestore (bản sao chỉ đọc cho realtime) ◀──────────────────────────────────┘
        instant_requests/{id}                       trạng thái, ứng viên lượt hiện tại, trạng thái từng lời mời (2 bên đọc phần của mình)
        instant_tracks/{id}                         vị trí hiện tại của nhiếp ảnh gia khi đang đến
        instant_offers/{photographerId}/items/{id}  các lời mời đang chờ của người đó (chỉ người đó đọc)
```

- **Thư mục**: `services/dispatch/` (cạnh `services/recommender/`, `services/api/` của backend giai đoạn 2). Hợp đồng [`services/dispatch/api/openapi.yaml`](../../../services/dispatch/api/openapi.yaml), phiên bản `/v1`, gồm cả dạng bản sao Firestore (`*Mirror`). Domain thuần ở `packages/dispatch-core`.
- **Gọi dịch vụ**: ứng dụng gọi thẳng HTTPS kèm Firebase ID token (cùng cách kiểm token với backend giai đoạn 2), không qua callable.
- **Module**:
  - `domain/` (TypeScript thuần): máy trạng thái, luật gợi ý và loại trừ, chấm điểm, luật lời mời (hạn, tối đa 3 mỗi người, người thắng), tính tiền và huỷ.
  - `presence`: bật/tắt sẵn sàng, cập nhật vị trí → `GEOADD online:{cityId}` + `presence:{uid}` TTL 10 phút.
  - `matcher` → **`recommender`**: `GEOSEARCH` theo bán kính, lọc theo bảng loại trừ, chấm điểm, trả 5 người kèm lý do; ghi `instant_candidates`. Không giữ chỗ.
  - `offers`: nhận danh sách người khách chọn, kiểm lại từng người (còn sẵn sàng, chưa đủ 3 lời mời: `INCR offers:{uid}` có kiểm giới hạn), tạo lời mời song song, gửi FCM, ghi `instant_offers/{uid}/items/{id}`, đặt việc hẹn giờ 60 giây; "Nhận" là một giao dịch PostgreSQL thành công chỉ khi lời mời còn hạn và yêu cầu còn `searching`; người thắng rút mọi lời mời khác.
  - `tracking`, `payments`, `api`: như trước (`tracking` ghi đè `instant_tracks/{id}`, ETA Goong tối đa 1 lần/phút; `payments` giữ, hoàn, chia tiền qua sổ cái chung).
- **Triển khai**: Cloud Run (hoặc container trong Docker Compose của backend giai đoạn 2 khi chạy local), Redis có lưu bền, PostgreSQL dùng chung cơ sở dữ liệu của backend giai đoạn 2 (schema `dispatch`).
- **Vì sao không chỉ Firestore**: nhiều thành phố từ đầu; vị trí cập nhật liên tục; cần khoá chống hai người cùng thắng và hẹn giờ chính xác. Firestore chỉ là kênh realtime cho app ở giai đoạn đầu.

## 6. API (tóm tắt; hợp đồng đầy đủ ở `services/dispatch/api/openapi.yaml`)

| Thao tác | Ai gọi | Ghi chú |
|---|---|---|
| `GET /v1/packages?cityId=` | cả hai | gói, giá hiện tại (đã nhân hệ số), phiên bản bảng giá, ước lượng thời gian có người nhận |
| `POST /v1/requests` | khách | `{packageId, genre, meetPoint{lat,lng,address}, note}` → `{requestId, amount, round: 1, candidates[≤5]}` (yêu cầu ở `choosing`, chưa thu tiền); lỗi `phone_required`, `outside_service_area` |
| `POST /v1/requests/{id}/candidates` | khách | `{skipped: [photographerId]}` → lượt tiếp theo `{round, candidates[≤5]}`; chỉ khi `choosing`; hết ứng viên → `candidates: []` |
| `POST /v1/requests/{id}/invite` | khách | `{photographerIds[1..5], skipped: [photographerId]}`; lượt đầu → `{paymentUrl}` (lời mời gửi sau khi cổng báo đã trả); lượt sau → `{invited[], unavailable[]}`; lỗi `price_changed`, `not_eligible` (id ngoài lượt hiện tại), `no_match` (tất cả đã bận) |
| `POST /v1/requests/{id}/cancel` | khách / nhiếp ảnh gia | trả `{refund, fee}` đã tính; khách gọi trước với `dryRun: true` để hiện ở S13.08 |
| `POST /v1/requests/{id}/confirm-complete` | khách | |
| `PUT /v1/presence` | nhiếp ảnh gia | `{online, helpReady, location{lat,lng,accuracy}}`; lỗi `not_eligible{reasons[]}` |
| `POST /v1/offers/{id}/accept` · `/decline` | nhiếp ảnh gia | lỗi `offer_expired`, `already_assigned` |
| `POST /v1/requests/{id}/location` | nhiếp ảnh gia (đang đến) | `{lat,lng,accuracy,heading,speed}`; giới hạn 1 lần / 5 giây |
| `POST /v1/requests/{id}/arrive` · `/start` · `/finish` | nhiếp ảnh gia | `arrive` kiểm khoảng cách ≤ 200 m hoặc `force: true` có ghi nhật ký |
| `PUT /v1/instant-settings` | nhiếp ảnh gia | chấp nhận bảng giá `{priceListVersion}`, `helpReady` |

Mã lỗi trong `ErrorCode` (`data-model/domain-model.md`): `no_match`, `offer_expired`, `already_assigned`, `not_eligible`, `outside_service_area`, `price_changed`.

## 7. Dữ liệu

Thêm vào `data-model/relational-schema.md` (schema `dispatch`); id ULID, thời gian UTC, tiền VND số nguyên, enum là chuỗi:

| Bảng | Cột chính |
|---|---|
| `cities` | `id`, `name`, `boundary geography(Polygon)`, `surge numeric(3,2)`, `active` |
| `instant_packages` | `id`, `code`, `duration_min`, `photos`, `price_vnd`, `price_list_version`, `active` |
| `instant_requests` | `id`, `customer_id`, `package_id`, `city_id`, `genre`, `meet_point geography(Point)`, `meet_address`, `note`, `amount_vnd`, `payout_vnd`, `status`, `photographer_id?`, `round`, `paid_at?`, `search_deadline_at?`, `requested_at`, `assigned_at?`, `arrived_at?`, `started_at?`, `finished_at?`, `completed_at?`, `cancelled_at?`, `cancel_reason?`, `version` |
| `instant_candidates` (mới) | `request_id`, `round`, `photographer_id`, `rank`, `score`, `reasons jsonb`, `shown_at`, `customer_choice (liked\|skipped\|none)`, PK (`request_id`, `photographer_id`) |
| `instant_offers` | `id`, `request_id`, `photographer_id`, `round`, `offered_at`, `expires_at` (= `offered_at` + 60 giây), `outcome (pending\|accepted\|declined\|expired\|withdrawn)`, `decided_at?` |
| `photographer_instant_settings` | `photographer_id` PK, `price_list_version_accepted`, `help_ready`, `home_city_id`, `updated_at` |
| `photographer_reliability` | `photographer_id` PK, `offers`, `accepted`, `cancelled`, `no_show`, `updated_at` |

Chỉ mục: `instant_requests(status, city_id)`, `instant_offers(request_id)`, `instant_offers(photographer_id, outcome)`, `instant_candidates(request_id, round)`, GiST trên `meet_point` và `cities.boundary`. Vị trí sẵn sàng **không** lưu ở PostgreSQL (chỉ Redis, có TTL). Vị trí khi đang đến chỉ giữ điểm mới nhất; khi yêu cầu kết thúc, xoá `instant_tracks/{id}` và không lưu lịch sử điểm. `instant_candidates` giữ để không gợi ý lại một người và để đo chất lượng gợi ý (tỉ lệ được chọn, tỉ lệ nhận).

Firestore (bản sao, chỉ dịch vụ ghi): `instant_requests/{id}` (`status`, `customerId`, `round`, `candidates` [thông tin hiển thị của lượt hiện tại: tên, ảnh, đánh giá, ETA, lý do], `offers` [{photographerId, outcome}], `photographerId`, tóm tắt nhiếp ảnh gia, `etaMinutes`, `meetPoint` chỉ khi đã `assigned`, `searchDeadlineAt`, `updatedAt`), `instant_tracks/{id}`, `instant_offers/{photographerId}/items/{offerId}` (gói, kiểu chụp, khu phố, khoảng cách, thu nhập, `expiresAt`, `invitedCount`). Rules: client không ghi; `instant_requests` và `instant_tracks` chỉ khách và nhiếp ảnh gia đã nhận đọc; `instant_offers/{uid}/items` chỉ chủ đọc.

## 8. Màn hình (S13–S14)

| Mã | Màn | Route | Vai trò |
|----|-----|-------|---------|
| S13.01 | Chụp ngay: gói, kiểu chụp, điểm hẹn, giá; nút "Xem nhiếp ảnh gia phù hợp" | `/instant` | khách |
| S13.03 | Đang chờ trả lời (người đã mời và trạng thái từng người) | `/instant/:id` (`pending_payment` sau khi trả, `searching`) | khách |
| S13.05 | Đã có người nhận / đang đến (bản đồ, ETA) | `/instant/:id` (`assigned`, `en_route`, `arrived`) | khách |
| S13.06 | Đang chụp / chờ xác nhận hoàn thành | `/instant/:id` (`in_progress`, chờ xác nhận) | khách |
| S13.07 | Không tìm được người | `/instant/:id` (`no_match`) | khách |
| S14.01 | Live Shutter (công tắc, bảng giá, "Sẵn sàng hỗ trợ") | `/work/instant` | NAG |
| S14.02 | Lời mời việc (toàn màn, chồng thẻ tới 3 lời mời, mỗi thẻ đếm ngược 60 giây) | `/work/instant/offer/:offerId` | NAG |
| S14.03 | Đang đến / đã đến / đang chụp | `/work/instant/:id` | NAG |
| S13.08 | Huỷ chụp ngay (sheet) | `/instant/:id/cancel` | cả hai |
| **S13.02** | **Vuốt chọn nhiếp ảnh gia** (5 thẻ, tóm tắt người đã chọn, nút gửi lời mời) | `/instant/:id` (`choosing`) | khách |
| **S13.04** | **Đã match** (chuyển tiếp ~1,5 giây) | không có route riêng (lớp phủ trên S13.05/S14.03) | cả hai |

Một route `/instant/:id` hiển thị S13.02, S13.03, S13.05, S13.06, S13.07 theo trạng thái nghe từ Firestore; mỗi trạng thái bọc `ScreenCode` riêng. Hai màn mới của lần sửa này là S13.02 (vuốt chọn) và S13.04 (đã match), theo quy tắc mã use case của spec chính mục 2.02, S13.04. Bảng mã ở spec chính mục 2, `ScreenCodes` và mock được cập nhật cùng lúc.

**Chuỗi chính** (khoá ARB đặt khi viết plan): "Chụp ngay", "Nhiếp ảnh gia tới chỗ bạn trong khoảng 30–90 phút", "Xem nhiếp ảnh gia phù hợp", "Chọn người bạn thích", "Thanh toán {giá} và gửi lời mời", "Gửi lời mời", "Xem 5 người khác", "Hoàn tác", "Tiền được giữ an toàn và hoàn 100% nếu không có người nhận.", "Đang chờ trả lời", "{tên} đang xem lời mời", "{tên} vừa nhận việc khác", "Chưa ai nhận. Chọn thêm người nhé.", "Đã match với {tên}", "{tên} đến trong khoảng {n} phút", "Đã đến điểm hẹn", "Chưa tìm được nhiếp ảnh gia", "{số tiền} vẫn được giữ an toàn cho yêu cầu này. Huỷ yêu cầu thì hoàn đủ.", "Chọn thêm người", "Huỷ yêu cầu và hoàn {số tiền}", "Hiện chưa có nhiếp ảnh gia sẵn sàng gần bạn", "Live Shutter", "Sẵn sàng hỗ trợ", "Nhận việc trong {n} giây", "Khách đã chọn bạn trong {n} người", "Khách đã chọn được người khác", "Đang nhận việc chụp ngay" (thông báo bền Android).

**Quy ước UI** (theo spec chính và `shared-components.md`): một nút chính mỗi màn; nút Huỷ là chữ đỏ mở S13.08, xác nhận huỷ là nút đỏ trong sheet; số tiền hoàn luôn hiện bằng chữ trước khi xác nhận; **S13.02**: thẻ vuốt luôn có nút ♥ / ✕ / Hoàn tác (≥ 48dp, có nhãn đọc màn hình) để không phụ thuộc cử chỉ; khi giảm chuyển động bật, thẻ đổi tức thì thay vì bay đi; **S14.02** có vùng chạm lớn (Nhận ≥ 56dp), đếm ngược bằng số và vòng, không chỉ bằng màu; **S13.04** dùng `MatchOverlay`: một nét liền vẽ chiếc máy ảnh (1,8 giây), ống kính chớp một vòng sáng, hai avatar đáp vào giữa ống kính (không trái tim, không icon tròn; giảm chuyển động thì hiện ngay khung cuối), tự đi tiếp sau khoảng 3 giây, có nút "Tiếp tục" cho người dùng trình đọc màn hình, giảm chuyển động thì không có hiệu ứng; bản đồ có nút "Về vị trí của tôi" và nhãn chữ cho mọi ghim.

## 9. Vị trí, pin và riêng tư

| Trạng thái | Nguồn vị trí | Tần suất | Độ chính xác |
|---|---|---|---|
| Nhiếp ảnh gia sẵn sàng, không có việc | dịch vụ vị trí khi di chuyển | khi đi > 300 m hoặc 5 phút một lần | thấp (~100 m) |
| Đang đến | luồng vị trí | 10–15 giây | cao |
| Đã đến / đang chụp / tắt sẵn sàng | — | dừng | — |
| Khách | một lần ở S13.01 (spec chính 3c) | một lần | trung bình |

- **Android**: khi sẵn sàng hoặc đang đến, chạy foreground service loại `location` với thông báo bền "Đang nhận việc chụp ngay" (bắt buộc từ Android 14, `FOREGROUND_SERVICE_LOCATION`); xin `ACCESS_FINE_LOCATION` khi dùng app; **không** xin `ACCESS_BACKGROUND_LOCATION` (foreground service đủ cho việc đang mở). Thông báo có nút "Tắt".
- **iOS**: quyền "Khi dùng app"; khi sẵn sàng/đang đến bật `allowsBackgroundLocationUpdates` với `showsBackgroundLocationIndicator = true` (chấm xanh trên thanh trạng thái), `UIBackgroundModes` gồm `location`. Đây là ngoại lệ có chủ đích so với kế hoạch bật iOS (vốn cấm `UIBackgroundModes`); kế hoạch của Chụp ngay cập nhật test đó. Không bao giờ xin "Luôn luôn".
- **Tự tắt**: 30 phút sẵn sàng mà không mở app → thông báo "Vẫn muốn nhận việc?"; không trả lời trong 5 phút → tự tắt. Pin dưới 15% → nhắc và đề nghị tắt.
- **Bản đồ** chỉ vẽ khi S13.05/S14.03 đang mở; tile cache của `maplibre_gl`; ghim di chuyển nội suy giữa hai điểm (không vẽ lại cả bản đồ).
- **Riêng tư**: địa chỉ chính xác chỉ gửi cho người đã nhận; trước đó lời mời chỉ có khu phố và khoảng cách. Vị trí nhiếp ảnh gia chỉ khách của yêu cầu thấy, chỉ khi đang đến. Không lưu lịch sử điểm. Số điện thoại vẫn theo luật mở khoá liên hệ (spec chính 3b).
- **Ngưỡng pin** (thêm vào `docs/testing/battery-and-performance.md`): sẵn sàng 1 giờ ≤ 3% pin; đang đến 30 phút ≤ 6%; GPS tắt hẳn trong 10 giây sau "Đã đến" hoặc tắt sẵn sàng.


## 10. Lỗi và tình huống biên

| Tình huống | Xử lý |
|---|---|
| Thanh toán lỗi hoặc huỷ ở cổng | Yêu cầu ở `payment_failed`, chưa mời ai; S13.02 giữ lựa chọn để thử lại |
| Người khách chọn vừa bận/tắt sẵn sàng/đủ 3 lời mời lúc gửi | Bỏ người đó, mời những người còn lại, S13.03 báo "{tên} vừa nhận việc khác"; tất cả đều bận → về `choosing` với lượt mới, không trừ thời gian chờ thanh toán |
| Hai nhiếp ảnh gia cùng bấm Nhận | Giao dịch PostgreSQL chọn một người thắng; người kia thấy "Khách đã chọn được người khác" (`already_assigned`) |
| Một nhiếp ảnh gia nhận hai yêu cầu cùng lúc | Giao dịch "Nhận" kiểm người đó chưa có yêu cầu đang chạy; lời mời thứ hai trả `already_assigned` cho chính người đó và bị rút |
| Lời mời hết hạn đúng lúc bấm Nhận | Dịch vụ là trọng tài theo thời gian server; quá hạn trả `offer_expired` |
| Khách mất mạng khi đang chờ | Dịch vụ vẫn chạy lời mời; app nghe lại Firestore khi có mạng; nếu đã về `choosing`, S13.02 hiện lượt mới |
| Khách bỏ S13.02 giữa chừng (chưa trả tiền) | Quá 30 phút → `abandoned`, không có tiền nào liên quan |
| Khách bỏ S13.02 giữa chừng (đã trả, đang ở lượt sau) | Mốc 10 phút vẫn chạy; hết giờ → `no_match`, tiền vẫn treo; app nhắc khách quay lại chọn tiếp hoặc huỷ |
| FCM trễ hoặc mất | Lời mời vẫn hết hạn sau 60 giây; app nhiếp ảnh gia đang sẵn sàng nghe `instant_offers/{uid}/items` nên vẫn thấy nếu đang mở |
| Nhiếp ảnh gia mất tín hiệu khi đang đến | Quá 3 phút không có vị trí: khách thấy "Đang chờ cập nhật vị trí"; trễ quá 15 phút so với ETA ban đầu: khách huỷ được với hoàn 100% |
| Goong lỗi hoặc hết hạn mức | ETA ước tính (đường chim bay × 1,4, 20 km/h) và ghi "ước tính"; bản đồ hiện lỗi tải tile nhưng vẫn có ETA và nút liên hệ |
| Khách ở ngoài thành phố đã mở | `outside_service_area`; S13.01 báo và gợi ý đặt lịch thường |
| Giá đổi giữa lúc xem và lúc trả | `price_changed` khi gửi lời mời lần đầu; S13.02 hiện giá mới và hỏi lại |
| Nhiếp ảnh gia bấm "Đã đến" khi còn xa | Từ chối nếu > 200 m; cho xác nhận với lý do nếu độ chính xác GPS kém (> 100 m), ghi nhật ký |
| Khách không xác nhận hoàn thành | Tự hoàn thành 2 giờ sau "Hoàn thành" của nhiếp ảnh gia; khiếu nại trong 24 giờ → `disputed` |
| Dịch vụ điều phối sập | Nút "Chụp ngay" ẩn (cờ cấu hình từ `GET /v1/packages` lỗi); yêu cầu đang dở tiếp tục khi dịch vụ lên lại nhờ trạng thái trong PostgreSQL và việc hẹn giờ lưu bền trong Redis |

## 11. Kiểm thử

- **Domain (unit, không hạ tầng)**: mọi chuyển trạng thái hợp lệ và bị từ chối (gồm `choosing ↔ searching`, `abandoned`); luật gợi ý (đủ 5 người, nới bán kính, nhóm mở rộng chỉ lấp chỗ, loại người đã từ chối/hết hạn/bị bỏ qua/đang bận/đủ 3 lời mời); chấm điểm và lý do; luật lời mời (60 giây, người thắng đầu tiên, rút lời mời còn lại và lời mời khác của người thắng); mọi dòng bảng huỷ mục 4, tổng tiền không lệch 1 ₫; làm tròn giá với hệ số; mốc 10 phút tính lại khi nhiếp ảnh gia huỷ; `no_match` không tự hoàn, chỉ hoàn khi khách huỷ.
- **Dịch vụ (Redis + PostgreSQL thật, Docker Compose của backend giai đoạn 2)**: 5 người cùng bấm Nhận một yêu cầu → đúng một người thắng, bốn lời mời `withdrawn`; một nhiếp ảnh gia nhận hai yêu cầu cùng lúc → chỉ một thành công; không ai có quá 3 lời mời đang chờ khi 50 khách cùng mời; hết 60 giây không ai nhận → về `choosing`; hết 10 phút → `no_match` **không có bút toán hoàn**, tiền vẫn `held`; huỷ từ `no_match` → bút toán hoàn 100%; TTL vị trí làm người đó bị loại khỏi gợi ý; dịch vụ khởi động lại giữa chừng vẫn tiếp tục lời mời đang chờ.
- **Tải**: script sinh 2.000 nhiếp ảnh gia ở 3 thành phố và 100 yêu cầu/phút trong 10 phút, mỗi yêu cầu mời 3 người. Ngưỡng: tạo lượt gợi ý p95 < 300 ms; gửi lời mời tới FCM p95 < 2 giây; không ai thắng hai lần, không lời mời vượt giới hạn.
- **App (widget)**: S13–S14 ở 320dp, chữ 1,3×, sáng và tối, `expectIdle`; S13.02 vuốt phải/trái và nút ♥/✕/Hoàn tác cho cùng kết quả, giảm chuyển động thì không có hiệu ứng bay; S13.03 cập nhật từng dòng trạng thái từ bản sao Firestore; S14.02 chồng 3 thẻ, mỗi thẻ đếm ngược đúng giây; S13.08 hiện đúng số tiền từ `dryRun`.
- **App (integration, bản giả)**: luồng đầy đủ khách + nhiếp ảnh gia trên hai `ProviderScope`; khách chọn 3 người, người thứ hai nhận; không ai nhận → lượt 2 → match; nhiếp ảnh gia huỷ rồi khách chọn lại; khách huỷ ở từng mốc.
- **Rules**: client không ghi `instant_*`; người ngoài không đọc được `instant_requests`/`instant_tracks`; `instant_offers/{uid}/items` chỉ chủ đọc.
- **Pin (tay, máy thật)**: theo hướng dẫn kiểm tra pin với ba kịch bản: sẵn sàng 1 giờ không có việc; một chuyến đang đến 30 phút; bật rồi tắt sẵn sàng (GPS tắt trong 10 giây). Android và iOS.

## 12. Kế hoạch triển khai (thứ tự)

| # | Kế hoạch | Phụ thuộc |
|---|---|---|
| I1 | Spec này, mock S13–S14, bảng mã, `ErrorCode`, schema | — |
| I2 | `packages/dispatch-core` (TypeScript thuần): máy trạng thái, gợi ý 5 người, luật lời mời, tiền | backend giai đoạn 1 (cấu trúc TypeScript) |
| I3 | Dịch vụ điều phối: presence, recommender, offers song song, tracking, payments (giả), API, FCM, bản sao Firestore, test đồng thời và tải | I2, backend giai đoạn 2 (Docker Compose, PostgreSQL) |
| I4 | App nhiếp ảnh gia: S14 (chồng lời mời, 60 giây), S13.04, `PresenceRepository`, foreground service, tracking | I3, kế hoạch 2b (liên hệ), 2d (hồ sơ) |
| I5 | App khách: S13.01, S13.02 vuốt chọn, S13.03 chờ trả lời, S13.05–S13.07, S13.08, S13.04, bản đồ Goong, `InstantBookingRepository` | I3, kế hoạch 2a (số điện thoại), 3a (vị trí), 4b (cổng giả trong app) |
| I6 | Thanh toán thật và escrow cho chụp ngay (thu ở lần gửi lời mời đầu) | bước 4 (thanh toán), spec chính 3g |

Các kế hoạch I2–I6 viết ngày 2026-10-01 theo cách mời lần lượt; **viết lại theo spec này trước khi chạy**.

## 13. Câu hỏi mở

1. Bảng giá v1 (giá từng gói theo thành phố, `payoutRate` 80%, hệ số cao điểm và khung giờ) cần chủ sản phẩm chốt.
2. Danh sách thành phố mở đầu tiên và ranh giới (polygon).
3. Có bắt nhiếp ảnh gia đặt cọc/ký cam kết riêng cho chụp ngay không (để giảm bỏ việc)?
4. Khoá API Goong (Maps, Autocomplete, Distance Matrix): tài khoản, hạn mức, và cách cấp khoá cho app (khoá giới hạn theo bundle/package).
5. Pháp lý: lưu vị trí thời gian thực của nhiếp ảnh gia (đồng ý rõ ràng ở S14.01, chính sách quyền riêng tư).
6. Chính sách khi khách báo nhiếp ảnh gia không đúng người trong hồ sơ (đối chiếu ảnh đại diện ở S13.05, nút báo cáo).
7. Thẻ vuốt có cần nút "Xem hồ sơ đầy đủ" (mở S03.01 rồi quay lại S13.02 giữ nguyên vị trí) ngay ở v1 không? Spec này để v1 chỉ có thẻ.
8. Nhiếp ảnh gia có nên thấy rằng khách đã mời cả người khác ("trong {n} người") không? Spec này đề xuất có, để họ hiểu vì sao cần nhận nhanh, nhưng không nêu tên.
9. Tiền treo của yêu cầu ở `no_match` mà khách không quay lại: giữ vô thời hạn theo quyết định hiện tại. Có cần nhắc định kỳ (ví dụ sau 24 giờ, 7 ngày) hay một mốc tự huỷ và hoàn sau thời gian dài không? Liên quan pháp lý giữ tiền hộ (spec chính câu hỏi mở 19).
