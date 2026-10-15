# Dịch vụ đi kèm khi đặt lịch (S04, S08)

Ngày: 2026-10-08 · Trạng thái: đang làm (#190, [#232](https://github.com/thanhngochoang/booking/pull/232)) · Dựa trên: `2026-10-06-payments-payouts-design.md` (trả 100% trước, giữ, nhả hai mốc), `2026-10-05-provider-types-portfolio-jobs-design.md` (ba loại nhà cung cấp), `2026-10-06-studio-members-design.md` (S26), `2026-10-07-studio-recruiting-design.md` (S27), plan `2026-10-07-s04-booking-payment.md` (`buildBookingDraft`, Decision 23). Spec đi cùng: điểm chụp đang hot (spec A, viết sau), dùng lại spec này.

## 1. Mục tiêu

Khi đặt lịch, khách thêm được các dịch vụ đi kèm mà thợ hoặc studio cung cấp: trang điểm, chỉnh thêm ảnh, xe đưa đón, trang phục… Tiền dịch vụ cộng vào booking, trả trước và giữ như tiền gói. Không thêm bước đặt lịch mới.

## 2. Quyết định đã chốt

| # | Quyết định | Nguồn |
|---|---|---|
| D1 | **Phase 1: nhà cung cấp tự khai** dịch vụ đi kèm của mình. Đối tác riêng (chuyên viên trang điểm, nhà xe có tài khoản riêng) để **Phase 2**. | chủ dự án 2026-10-08 (phương án C) |
| D2 | Nhà cung cấp chịu trách nhiệm với khách về mọi dịch vụ đi kèm. Thuê người ngoài là việc riêng của họ, ngoài app (như thù lao CTV, S27 R5). | chủ dự án |
| D3 | Ba cách tính: `per_booking` (một lần), `per_person` (theo người), `per_item` (theo số lượng). Tối đa **10** dịch vụ đang bật mỗi nhà cung cấp. | chủ dự án |
| D4 | Chọn dịch vụ ngay ở **S04.01** (khối "Thêm dịch vụ"); không thêm bước. Có xe đưa đón thì bước địa điểm hỏi thêm **điểm đón**. | chủ dự án |
| D5 | **Chưa cho thêm hoặc bớt dịch vụ sau khi đã thanh toán** (Phase 1). Muốn đổi: nhắn thợ, huỷ rồi đặt lại theo chính sách huỷ. | chủ dự án |
| D6 | Server tính giá từ dữ liệu của nhà cung cấp; app chỉ gửi `addonId` + `qty`. Booking lưu bản chụp dịch vụ (như `serviceSnapshot`). | chủ dự án |
| D7 | Luật tiền giữ nguyên, áp dụng cho **tổng** (gói + dịch vụ): trả 100%, hai mốc, bảng hoàn tiền S05.03, thuế khấu trừ, `platformFeeBp`. Dịch vụ không được thực hiện: khách mở khiếu nại S18. | chủ dự án, spec thanh toán M2 |
| D8 | Báo giá (S15–S16) và Chụp ngay (S13–S14) **không có** dịch vụ đi kèm ở Phase 1. Studio (S26/S27): dịch vụ là của studio. | chủ dự án |

## 3. Dữ liệu

### 3.1 `ServiceAddon`

Firestore: `photographers/{uid}/addons/{addonId}` (cạnh `services/{id}`), ID ULID. Chỉ server ghi, qua callable `saveAddon`/`deleteAddon` (§6.2); mọi người đọc được dịch vụ `active` (giống `services`), chủ đọc được cả dịch vụ đã tắt.

| Trường | Ghi chú |
|---|---|
| `id`, `providerId` | Studio: dịch vụ thuộc studio (`providerId` = uid của studio) |
| `kind` | `makeup` \| `retouch` \| `transport` \| `outfit` \| `other` (mã chuỗi; app dùng để chọn icon và nhóm) |
| `name` | 2–60 ký tự. Lọc số điện thoại, Zalo, link bằng `findContactLeak` (S15) |
| `description?` | Tối đa 200 ký tự, cùng bộ lọc |
| `price` | Số nguyên VND, 10.000–50.000.000 |
| `unit` | `per_booking` \| `per_person` \| `per_item` |
| `maxQty` | 1–10; `per_booking` luôn là 1 |
| `serviceIds` | Danh sách gói áp dụng; rỗng = mọi gói |
| `active` | Tắt thì khách không thấy; booking cũ không đổi |
| `createdAt`, `updatedAt` | UTC |

Bất biến: tối đa 10 bản ghi `active = true` mỗi `providerId`; `saveAddon` kiểm khi tạo hoặc bật.

Icon theo `kind` (`AppIcons`, Material Symbols Rounded): `makeup` → `face_retouching_natural` (`AppIcons.face`, đã có), `retouch` → `auto_awesome` (`AppIcons.autoAwesome`, đã có), `transport` → `directions_car`, `outfit` → `checkroom`, `other` → `add_circle`. Ba biểu tượng sau là mới, thêm vào `AppIcons` và gallery.

### 3.2 Booking

| Trường mới | Ghi chú |
|---|---|
| `addons: AddonLine[]` | `{addonId, kind, name, unit, unitPrice, qty, amount}`; `amount = unitPrice × qty`. Rỗng khi không chọn. |
| `pickup?: {name, point?}` | Bắt buộc khi có dòng `kind = transport`; giống `place` (tên ≥ 3 ký tự). Chỉ hai bên của booking đọc được. |

Bất biến mới (domain, có test): `tổng booking = serviceSnapshot.price + Σ addons.amount`. Mọi chỗ đang dùng giá gói làm số tiền thanh toán (`upfrontAmount`, hai mốc, hoàn tiền, thuế, phí nền tảng) đổi sang dùng tổng này.

### 3.3 Mô hình quan hệ (`relational-schema.md`)

`service_addons(id, provider_id, kind, name, description, price_vnd, unit, max_qty, active, created_at, updated_at)`, `service_addon_services(addon_id, service_id)`, `booking_addons(booking_id, addon_id, kind, name, unit, unit_price_vnd, qty, amount_vnd)`, `bookings.pickup_name`, `bookings.pickup_point`.

## 4. Nhà cung cấp khai dịch vụ (S08)

- **S08.06 · Dịch vụ đi kèm** (`/me/addons`): mở từ Cài đặt (nhóm Nhận việc, cạnh "Gói dịch vụ") và từ bước gói của S08.01 ("Thêm dịch vụ đi kèm"). Danh sách nhóm theo loại; mỗi dòng: icon, tên, giá + cách tính ("800.000₫ / người"), "Áp dụng: mọi gói" hoặc tên gói, công tắc bật/tắt. Dòng đầu: "{n}/10 dịch vụ đang bật". Nút chính "Thêm dịch vụ". Trống: "Chưa có dịch vụ đi kèm" / "Thêm trang điểm, chỉnh ảnh hay xe đưa đón để khách chọn khi đặt lịch."
- **S08.07 · Thêm/sửa dịch vụ đi kèm** (sheet): loại (chip đơn), tên, mô tả (tuỳ chọn), giá, cách tính (segmented: Một lần · Theo người · Theo số lượng), số lượng tối đa (chỉ khi theo người/số lượng), "Áp dụng cho" (Mọi gói / chọn gói), dòng nhắc "Bạn chịu trách nhiệm với khách về dịch vụ này, kể cả khi thuê người ngoài." Nút "Lưu". Sửa: thêm chữ đỏ "Xoá dịch vụ" → sheet xác nhận nút đỏ ("Booking đã đặt vẫn giữ dịch vụ này.").
- Lỗi dưới ô: "Tên 2–60 ký tự", "Giá từ 10.000₫ tới 50.000.000₫", "Bỏ số điện thoại, Zalo hoặc link ra khỏi nội dung", "Bạn đã bật đủ 10 dịch vụ. Tắt bớt một dịch vụ để bật dịch vụ này."
- Nhà cung cấp chưa được duyệt nhận đơn (S21) vẫn khai được, nhưng khách chưa thấy (giống gói).

## 5. Khách chọn dịch vụ (S04)

### 5.1 S04.01 · Chọn gói, khối "Thêm dịch vụ"

- Chọn gói xong, dưới danh sách gói hiện khối **"Thêm dịch vụ"**: các dịch vụ đang bật áp dụng cho gói đó, nhóm theo loại.
- Mỗi dòng: icon trong ô tròn, tên, mô tả một dòng, giá + cách tính. `per_booking`: ô tick bên phải. `per_person`/`per_item`: bộ đếm − n + (0 tới `maxQty`), mặc định 0.
- Nút chính duy nhất: **"Tiếp tục · {tổng}"**.
- Đổi gói: giữ dịch vụ còn áp dụng; bỏ dịch vụ không áp dụng và hiện thanh "Đã bỏ {tên} vì không áp dụng cho gói này".
- Không có dịch vụ nào áp dụng: khối không hiện.

### 5.2 S04.06 · Bước 3 · Địa điểm (mã mới)

Bước 3 trước nay không có mã; nay đặt **S04.06** vì có thêm ô. Khi có dòng `transport`: thêm ô **"Điểm đón"** (bản đồ nhỏ + tên, như ô địa điểm chụp) và dòng phụ "Chỉ thợ chụp cho bạn thấy điểm đón." Không có xe: bước giữ nguyên.

### 5.3 S04.03 · Xem lại & thanh toán

Bảng tiền liệt kê gói và từng dịch vụ ("Trang điểm · 2 người 1.600.000₫"), dòng **"Thanh toán 100% · {tổng}"**, nút chính "Thanh toán {tổng}". Câu "Tiền được giữ tới khi bạn nhận ảnh, chuyển cho thợ theo 2 mốc. Huỷ trước 48 giờ hoàn 100% số đã trả." áp dụng cho tổng. Có xe: thêm dòng "Điểm đón: {tên}".

### 5.4 Sau khi đặt

- **S05.02 · Chi tiết buổi chụp:** khối "Dịch vụ đi kèm" (icon, tên, số lượng, tiền) và "Điểm đón" nếu có.
- **S06.01 · thẻ yêu cầu của thợ:** thêm một dòng tóm tắt "+ Trang điểm ×2 · Xe đón".
- **S05.03 · Huỷ:** bảng hoàn tiền tính trên tổng; không đổi bố cục.
- Không thêm/bớt dịch vụ sau khi thanh toán (D5).

## 6. Server và tiền

### 6.1 Domain (`packages/domain`, không Firebase)

- `addon_pricing.ts`: `priceAddonLines(addons: ServiceAddon[], picks: {addonId, qty}[], serviceId): AddonLine[]` ném `DomainError`:
  - `addon_changed`: dịch vụ không tồn tại, đã tắt hoặc không còn thuộc nhà cung cấp;
  - `addon_not_applicable`: dịch vụ không áp dụng cho gói;
  - `invalid_argument`: `qty` ngoài `1..maxQty`, trùng `addonId`, quá 10 dòng.
- `bookingTotal(serviceSnapshot, addons) = price + Σ amount`.
- `requirePickup(addons, pickup)`: có `transport` mà thiếu `pickup` → `pickup_required`.
- `buildBookingDraft` (chủ là S04) nhận thêm `addons: readonly AddonLine[]` và `pickup?`; `amount = upfrontAmount(bookingTotal(...))`.
- Hai mốc, `computeRefund`, thuế khấu trừ, `platformFeeBp` nhận tổng (đổi điểm gọi, không đổi công thức).

### 6.2 Functions (`asia-southeast1`)

| Callable | Input | Output | Lỗi |
|---|---|---|---|
| `saveAddon` | `{addonId?, kind, name, description?, price, unit, maxQty, serviceIds, active}` | `{addonId}` | `invalid_argument`, `contact_leak`, `addon_limit` (đủ 10 đang bật), `permission_denied` |
| `deleteAddon` | `{addonId}` | `{}` | `not_found`, `permission_denied` |
| Đường tạo booking theo gói (callable hiện có của S04) | thêm `addons: [{addonId, qty}]`, `pickup?` | như cũ | thêm `addon_changed`, `addon_not_applicable`, `pickup_required` |

App gặp `addon_changed` thì tải lại khối "Thêm dịch vụ" và hiện "Dịch vụ đi kèm vừa thay đổi, kiểm tra lại trước khi thanh toán".

### 6.3 Rules

- `photographers/{uid}/addons/{id}`: đọc công khai khi `active`; chủ đọc tất cả của mình; **không ai ghi trực tiếp** (chỉ `saveAddon`/`deleteAddon`).
- `bookings/{id}.pickup`, `.addons`: nằm trong tài liệu booking, chỉ hai bên đọc (rules hiện có). Không chép `pickup` sang bất kỳ tài liệu công khai nào.
- Test rules viết kèm; CI chạy (không chạy local).

### 6.4 Các đường đặt khác

- **Báo giá (S15–S16):** không gắn dịch vụ; thợ gộp vào giá báo. `buildBookingDraft` nhận `addons = []`.
- **Chụp ngay (S13–S14):** không có dịch vụ.
- **Studio (S26/S27):** dịch vụ của studio; thợ hoặc CTV được giao chụp như cũ, thù lao CTV không đổi. Thẻ việc của CTV (S27.07) **không** hiện giá dịch vụ, chỉ tên dịch vụ (để biết có trang điểm hay xe).

## 7. Mã màn và mock

| Mã | Màn | Loại |
|---|---|---|
| S04.01-addons | Chọn gói + khối "Thêm dịch vụ" | biến thể |
| **S04.06** | Bước 3 · Địa điểm, có ô "Điểm đón" | mới |
| S04.03-addons | Xem lại & thanh toán có từng dòng dịch vụ | biến thể |
| S05.02-addons | Chi tiết buổi chụp có dịch vụ + điểm đón | biến thể |
| **S08.06** | Dịch vụ đi kèm (danh sách) | mới |
| **S08.07** | Thêm/sửa dịch vụ đi kèm (sheet) | mới |

Đồng bộ: `docs/design/ui-mock.html`, bảng mã spec chính §2, `lib/core/screen_codes.dart`, `specs/screens/booking.md`, `specs/screens/photographer.md`.

## 8. Test

- **Domain:** tính tiền ba cách; bất biến tổng; `addon_changed`, `addon_not_applicable`, `qty` ngoài khoảng, trùng `addonId`, `pickup_required`; hoàn tiền và hai mốc trên tổng.
- **Functions:** `saveAddon` (giới hạn 10, lọc liên hệ, chỉ chủ); tạo booking với dịch vụ lấy giá từ server dù app gửi giá khác; `addon_changed` khi tắt/đổi giá giữa chừng; nhà cung cấp chưa nhận đơn vẫn bị chặn như cũ.
- **Rules (viết, CI chạy):** không ai ghi trực tiếp `addons`; khách đọc được dịch vụ đang bật, không đọc được dịch vụ đã tắt của người khác; `pickup` chỉ hai bên đọc.
- **Flutter:** khối "Thêm dịch vụ" (tick, bộ đếm tới `maxQty`, tổng trên nút, đổi gói bỏ dịch vụ không áp dụng); ô "Điểm đón" chỉ khi có xe; bảng tiền S04.03; S05.02 khối dịch vụ; S08.06/S08.07 (đếm n/10, lỗi form, xoá có xác nhận); 320 dp và chữ 1,3×; theme tối và sáng.

## 9. Chi phí Google

- Firestore: S04.01 đọc thêm tối đa 10 tài liệu `addons` mỗi lần mở gói của một thợ; S08.06 đọc ≤ 10 tài liệu. Không có job định kỳ, không có Storage mới.
- Functions: `saveAddon`/`deleteAddon` vài lần mỗi nhà cung cấp; tạo booking không thêm lần gọi.
- Kết luận: **≈ +$0/tháng** ở mức 1.000 và 10.000 người dùng/tháng (đơn giá theo `2026-10-07-google-cloud-costs.md`).

## 10. Phase 2 (issue riêng)

- **Đối tác dịch vụ riêng:** chuyên viên trang điểm, nhà xe có tài khoản, hồ sơ, xác minh, đánh giá và nhận tiền riêng; booking chia tiền nhiều bên.
- Thêm/bớt dịch vụ sau khi đã thanh toán (thanh toán bù, hoàn một phần).
- Dịch vụ đi kèm trong báo giá (S15–S16).

## 11. Câu hỏi còn mở (đã có mặc định)

| Câu hỏi | Mặc định |
|---|---|
| Giới hạn giá 10.000₫–50.000.000₫ mỗi dịch vụ có hợp lý? | dùng |
| Khách xem được dịch vụ đi kèm trên hồ sơ thợ (S03.01, tab Gói) trước khi đặt? | có, liệt kê dưới các gói, chỉ đọc |
| Thợ không làm một dịch vụ đã nhận tiền: tính vào cà chua/gạch? | không tự động; khách tự đánh giá, staff xử lý khiếu nại |
