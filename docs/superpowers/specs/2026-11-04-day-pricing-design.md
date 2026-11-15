# Bảng giá theo ngày và thiết kế lại phần nhập gói (S08.08–S08.10)

> **Đã thay thế 2026-11-06** bởi `2026-11-06-day-pricing-redesign.md` (#316 mở lại: UX và ngày lễ fix cứng). Giữ lại để đối chiếu với PR #326.

Ngày: 2026-11-04 · Trạng thái: đã làm (PR #326), đã bị thay thế · Issue: #316 (gộp #317 ngày lễ, #318 từng thứ) · Dựa trên: spec chính `2026-10-01-remaining-screens.md` (S04, S08), `2026-10-05-provider-types-portfolio-jobs-design.md` (gói, `BookingTerms`), `2026-10-08-booking-addons-design.md` (tổng tiền booking), `2026-10-08-trending-spots-design.md` (`SpotSchedule.priceFrom`), `data-model/domain-model.md` (`Service`).

## 1. Mục tiêu

Hiện mỗi gói chỉ có một giá. Thợ ảnh thường lấy giá cuối tuần cao hơn ngày thường, giá ngày lễ và mùa cưới cao hơn nữa. Vì vậy thợ phải chọn một giá trung bình, hoặc báo thêm phí qua tin nhắn, mà phí báo qua tin nhắn thì nằm ngoài luồng thanh toán giữ tiền. Spec này làm ba việc:

1. **Giá theo ngày cho mỗi gói**:
   - hai mức: ngày thường (T2–T6) và cuối tuần (T7–CN);
   - tuỳ chọn giá riêng cho từng thứ;
   - tuỳ chọn giá **ngày đặc biệt** (lễ, Tết, ngày riêng của thợ).
2. **Khách thấy đúng giá của ngày mình chọn** trước khi trả tiền. Booking giữ giá đó.
3. **Thiết kế lại phần nhập gói**:
   - màn quản lý gói riêng (S08.08);
   - màn thêm/sửa gói có bảng giá (S08.09), S08.01 bước 2 dùng chung màn này;
   - màn ngày đặc biệt (S08.10).

## 2. Quyết định

| # | Quyết định | Nguồn |
|---|---|---|
| P1 | Mỗi gói có **giá theo 7 thứ**. Mặc định nhập **hai mức**: ngày thường T2–T6 và cuối tuần T7–CN. Bật "Chỉnh từng ngày" để sửa từng thứ. | chủ dự án 2026-11-04 (#316, #318) |
| P2 | Mỗi gói có tuỳ chọn **giá ngày đặc biệt**, một số tiền cụ thể (không nhập theo phần trăm). Giá này áp cho **ngày lễ chung** (staff nhập theo năm) và **ngày riêng của thợ**. | chủ dự án (#317); mặc định trong issue |
| P3 | Giá một ngày tính theo thứ tự: ngày đặc biệt (nếu gói có giá đặc biệt) → giá của thứ đó. Chỉ một hàm tính, `priceForDay`, theo giờ Việt Nam. | thiết kế |
| P4 | Booking chụp giá của ngày vào `serviceSnapshot.price` lúc đặt. Thợ đổi giá hoặc thêm ngày đặc biệt sau đó thì booking cũ **không đổi**. | mặc định trong issue |
| P5 | **Đổi lịch** sang ngày có giá khác thì **giữ giá đã trả**: không thu thêm, không hoàn chênh lệch. | mặc định trong issue |
| P6 | "Từ {giá}" (`startingPrice`), bộ lọc giá và `SpotSchedule.priceFrom` lấy **giá thấp nhất trong tuần** của các gói đang bật. Không tính giá ngày đặc biệt. | mặc định trong issue |
| P7 | Không có giá theo khung giờ trong ngày. Dịch vụ đi kèm, gói chia suất (S29), Chụp ngay (S13–S14) và báo giá (S15–S16) **giữ nguyên**. | mặc định trong issue |
| P8 | Dữ liệu cũ không phải chuyển đổi. `price` vẫn là bắt buộc và mang nghĩa **giá ngày thường**. Gói không có `dayPrices` thì cả 7 ngày lấy `price`. | thiết kế |
| P9 | Luật tiền, giữ tiền, hoàn huỷ, chỉ nhà cung cấp đã duyệt mới nhận đơn: giữ nguyên. | CLAUDE.md |

## 3. Dữ liệu

### 3.1 `photographers/{uid}/services/{id}` (app ghi, rules kiểm tra)

Thêm vào `Service`:

| Trường | Kiểu | Ghi chú |
|---|---|---|
| `price` | int > 0 | **Không đổi tên**. Giá ngày thường, và là giá của mọi thứ khi không có `dayPrices`. |
| `dayPrices?` | map `{mon, tue, wed, thu, fri, sat, sun}` → int > 0 | Đủ 7 khoá nếu có. App ghi đủ 7 cả khi thợ chỉ nhập hai mức, ghi `price` = giá thứ Hai. Không có trường này = mọi ngày bằng `price`. |
| `specialPrice?` | int > 0 | Giá ngày đặc biệt. Không có = ngày đặc biệt tính như ngày thường của thứ đó. |
| `priceMode?` | `two_levels` \| `per_day` | Chỉ để màn sửa mở đúng chế độ. Không ảnh hưởng cách tính giá. |
| `order?` | int 0–999 | Thứ tự hiện ở S08.08, S03.01, S04.01. Không có = theo `createdAt`. |

Giới hạn giá vẫn như `price`: 1–1.000.000.000. `firestore.rules` (`validService`) mở thêm các khoá trên, kiểm tra kiểu và giới hạn. Kiểm tra "đủ 7 khoá" dùng `keys().hasOnly(...)` cộng `size() == 7`.

### 3.2 Ngày đặc biệt

- **Ngày lễ chung**: `holidays/{year}` = `{days: [{day: LocalDate, name}], updatedAt}`. Ai đã đăng nhập cũng đọc được; chỉ server ghi. Staff nhập bằng CLI `npm run holidays -- set 2027 --file holidays-2027.json` trong `app_flutter/firebase/functions`. Tết âm lịch nhập theo ngày dương. Seed emulator có năm hiện tại và năm sau, gồm Tết, 30/4–1/5, 2/9 và Giỗ Tổ.
- **Ngày riêng của thợ**: `photographers/{uid}/special_days/{id}` = `{name (2–40 ký tự), from: LocalDate, to: LocalDate, createdAt, updatedAt}`. Ràng buộc:
  - `to ≥ from`, mỗi khoảng ≤ 60 ngày, `to` không quá 365 ngày tới;
  - tối đa 20 khoảng mỗi thợ.

  Chủ ghi, người đã đăng nhập đọc. Riêng giới hạn 20 khoảng do app kiểm tra, vì rules không đếm được số tài liệu. Vượt giới hạn không gây sai giá, chỉ làm danh sách dài.
- Một ngày là **ngày đặc biệt** của thợ khi nó nằm trong `holidays/{year}.days` hoặc trong một khoảng ngày riêng của thợ đó.

### 3.3 Domain (`packages/domain/src/day_pricing.ts`)

```ts
type Weekday = 'mon' | 'tue' | 'wed' | 'thu' | 'fri' | 'sat' | 'sun';
interface PricedService { price: number; dayPrices?: Record<Weekday, number>; specialPrice?: number }
interface SpecialDays { holidays: readonly LocalDate[]; ranges: readonly { from: LocalDate; to: LocalDate }[] }

weekdayOf(day: LocalDate): Weekday                    // lịch Gregory, không phụ thuộc múi giờ máy
isSpecialDay(day, special: SpecialDays): boolean
priceForDay(s: PricedService, day: LocalDate, special: SpecialDays): { amount: number; kind: 'weekday' | 'weekend' | 'special' }
weekPrices(s): Record<Weekday, number>                 // dayPrices ?? 7 × price
priceRange(s): { min: number; max: number }           // trong tuần, không tính specialPrice
priceSummary(s): { kind: 'single' | 'two_levels' | 'per_day', weekday?: number, weekend?: number, min, max, special?: number }
validateServicePrices(input): void                    // DomainError('invalid_argument', field)
```

`kind` của `priceForDay` cho biết vì sao ngày đó có giá như vậy, để app ghi "(cuối tuần)" hoặc "(ngày lễ)". `weekend` nghĩa là T7/CN, dù chế độ nhập là hai mức hay từng thứ.

`computeStartingPrice` nhận danh sách gói và lấy `min(priceRange(s).min)` (P6).

### 3.4 Đặt lịch

- `createBooking` (gói thường và gói của lịch tại điểm S29) đọc ngày đặc biệt trong cùng giao dịch: `holidays/{năm của ngày chụp}` và các `special_days` của thợ có `to ≥ ngày`. Giá được tính bằng `priceForDay` và ghi vào `serviceSnapshot.price`.
- `expectedPrice` so với giá của **ngày đó**. Khác thì trả `price_changed`, như hiện nay.
- App cũ (gửi `expectedPrice = price`) đặt vào cuối tuần của gói có giá cuối tuần khác thì nhận `price_changed`, và màn hiện có thông báo "Giá vừa thay đổi". Kết quả an toàn, không ai trả sai tiền.
- `buildBookingDraft`, tổng tiền với dịch vụ đi kèm, và các mốc tiền đều dùng giá này.
- Đổi lịch (`reschedule`) không tính lại giá (P5).

### 3.5 Tóm tắt giá công khai

- Trigger `photographers/{uid}/services/{id}` hiện tính `startingPrice`. Nay tính theo P6, và thêm `priceSummary` của thợ:
  - `startingPrice`, `weekendFrom?` (giá cuối tuần thấp nhất, khi khác ngày thường);
  - `hasSpecialPrices` (có gói nào có `specialPrice` không).

  App dùng `priceSummary` cho thẻ thợ mà không cần đọc từng gói.
- `SpotSchedule.priceFrom` tính lại theo P6, dùng chung hàm.

## 4. Màn hình

### 4.1 S08.08 · Gói dịch vụ của tôi (`/me/packages`)

Lối vào:
- Hồ sơ của thợ: nút "Sửa gói" (thay chỗ đang mở `/setup/2`);
- Công việc → dòng "Gói và bảng giá";
- S08.06 (Dịch vụ đi kèm): liên kết "Gói dịch vụ".

Bố cục từ trên xuống:
1. Thanh tiêu đề "Gói dịch vụ".
2. Dòng "{n} gói đang bật".
3. **Thẻ gói**, mỗi gói một thẻ:
   - tên; dòng "2 giờ · 40 ảnh chỉnh · giao 3 ngày";
   - **dòng giá** theo `priceSummary`: "1.500.000₫" (một giá), "T2–T6 1,5M · T7–CN 1,8M" (hai mức), "1,5M–2,2M · theo ngày" (từng thứ), cộng " · Lễ 2,5M" khi có giá đặc biệt;
   - công tắc bật/tắt (ẩn gói); tay kéo để sắp thứ tự.

   Chạm thẻ → S08.09.
4. Dòng "Ngày đặc biệt · {n} ngày lễ chung, {m} khoảng ngày của bạn" → S08.10.
5. Nút chính "Thêm gói" → S08.09.

Trạng thái:
- Chưa có gói: trống, "Thêm gói đầu tiên để khách đặt được bạn".
- Tắt gói cuối cùng đang bật: hỏi lại "Khách sẽ không đặt được bạn cho tới khi bật lại một gói".

### 4.2 S08.09 · Thêm/sửa gói (`/me/packages/new`, `/me/packages/:id`)

Màn toàn trang (không dùng sheet, vì nội dung dài). Từ trên xuống:

1. **Thông tin gói**:
   - tên (2–60 ký tự);
   - thời lượng: chip 1, 2, 3, 4, 6, 8 giờ;
   - số ảnh chỉnh, giao sau mấy ngày (cùng một hàng).
2. **Bảng giá**:
   - `SegmentedTabs` gồm "Hai mức giá" (ngày thường T2–T6, cuối tuần T7–CN) và "Từng ngày".
   - Ở chế độ hai mức: hai ô "Ngày thường · T2–T6" và "Cuối tuần · T7–CN". Ô cuối tuần được điền sẵn bằng giá ngày thường khi thợ nhập ngày thường lần đầu. Dòng gợi ý "Thợ ảnh thường lấy cuối tuần cao hơn 10–30%" chỉ để tham khảo.
   - Ở chế độ từng ngày: 7 hàng T2…CN, mỗi hàng một ô giá; ô T7 và CN có nhãn "cuối tuần". Chuyển từ hai mức sang thì 7 ô điền sẵn từ hai mức. Chuyển ngược lại khi 7 giá chưa thành đúng hai mức thì hỏi "Dùng giá T2 cho ngày thường và giá T7 cho cuối tuần?".
3. **Ngày lễ và ngày đặc biệt**: công tắc "Giá riêng ngày đặc biệt". Bật thì hiện ô giá và dòng "Áp cho {n} ngày lễ chung và {m} khoảng ngày của bạn · Xem" (→ S08.10).
4. **Xem trước**: dải 7 ngày tới, mỗi ngày ghi thứ, ngày và giá rút gọn (ví dụ "T7 14/11 · 1,8M"); ngày đặc biệt có chữ "Lễ". Dòng "Khách đặt T7 14/11 trả 1.800.000₫ (chưa gồm dịch vụ đi kèm)".
5. Nút chính "Lưu gói". Khi sửa có thêm chữ "Ẩn gói" (không xoá; gói đã đặt vẫn giữ).

Kiểm tra (lỗi hiện dưới ô):
- "Tên 2–60 ký tự";
- "Giá phải lớn hơn 0" (mọi ô giá);
- "Giá tối đa 1.000.000.000₫".

Sửa giá chỉ áp cho booking mới, nên màn có dòng nhắc "Booking đã đặt giữ giá cũ" (P4).

### 4.3 S08.10 · Ngày đặc biệt (`/me/special-days`)

1. Mục "Ngày lễ chung {năm}": danh sách chỉ đọc (tên, ngày hoặc khoảng ngày). Có chip năm nay / năm sau.
2. Mục "Ngày riêng của bạn": danh sách khoảng ngày (tên, "T7 14/11 – CN 22/11", số ngày). Chạm một dòng để sửa; có chữ đỏ "Xoá" kèm xác nhận.
3. Ghi chú: "Gói có giá ngày đặc biệt sẽ dùng giá đó cho các ngày này. Gói không có giá đặc biệt tính như ngày thường. Muốn nghỉ hẳn thì đánh dấu nghỉ trong Lịch."
4. Nút chính "Thêm khoảng ngày" mở sheet: tên, từ ngày, tới ngày (lịch tháng), nút "Lưu".

### 4.4 Thay đổi ở màn đã có

| Màn | Thay đổi |
|---|---|
| S08.01 bước 2 | Danh sách gói giống S08.08 (rút gọn, không có tay kéo). "Thêm gói" mở S08.09 với nút "Lưu gói" quay về bước 2; form nhập ngay trong bước 2 bị bỏ. |
| S03.01 Hồ sơ thợ, thẻ gói | Dòng giá theo `priceSummary`. Chạm "Bảng giá" mở sheet chỉ đọc: 7 ngày, giá đặc biệt và các ngày áp dụng. |
| S04.01 Chọn gói | Giá bên phải: "1,5M–1,8M" khi giá thay đổi theo ngày, dưới tên có dòng "T7–CN 1,8M". Nút "Tiếp tục · từ 1.500.000₫" (chưa có ngày). Vào từ một ngày đã chọn (S29, lịch ở hồ sơ) thì hiện giá đúng của ngày đó. |
| S04.02 Ngày & giờ | Dưới mỗi số ngày có giá rút gọn khi khác giá ngày thường ("1,8M"); ngày đặc biệt có chấm và chú thích "Lễ". Nút "Tiếp tục · {giá của ngày đã chọn}". |
| S04.03 Xem lại | Dòng gói "Gói Chân dung 2 giờ · T7 14/11 (cuối tuần)", hoặc "(ngày lễ)". Tổng tiền tính theo giá đó. |
| `PhotographerCard` | "từ {startingPrice}" như cũ; thêm "· T7–CN từ {weekendFrom}" khi có và còn chỗ (bỏ trước tiên khi thẻ hẹp). |
| S06.01 Công việc | Thêm dòng lối vào "Gói và bảng giá" → S08.08. |

## 5. Mã màn và mock

| Mã | Màn | Loại |
|---|---|---|
| S08.08 | Gói dịch vụ của tôi | mới |
| S08.09 | Thêm/sửa gói (bảng giá) | mới (+ `-perday` từng thứ) |
| S08.10 | Ngày đặc biệt | mới (+ sheet thêm khoảng ngày) |
| S08.01-packages | Thiết lập bước 2 dùng danh sách mới | biến thể |
| S03.01-prices | Sheet bảng giá chỉ đọc ở hồ sơ thợ | biến thể |
| S04.01-dayprice, S04.02-dayprice, S04.03-dayprice | Giá theo ngày khi đặt | biến thể |

Đồng bộ: `docs/design/ui-mock.html`, bảng mã §2 của spec chính, `lib/core/screen_codes.dart`, `specs/screens/photographer.md` (S08.08–S08.10) và `specs/screens/booking.md` (biến thể S04).

## 6. Test

- **Domain**:
  - `weekdayOf` qua đủ 7 thứ và ngày 29/2;
  - `priceForDay`: một giá, hai mức, từng thứ;
  - ngày lễ chung, khoảng ngày riêng (ngày đầu, ngày cuối, ngoài khoảng), ngày đặc biệt khi gói không có `specialPrice`;
  - `priceRange` và `computeStartingPrice` không tính giá đặc biệt;
  - `validateServicePrices` (thiếu khoá, giá 0, giá quá lớn).
- **Functions**:
  - đặt T7 nhận giá cuối tuần, đặt ngày lễ nhận giá đặc biệt;
  - `expectedPrice` cũ trên ngày cuối tuần → `price_changed`;
  - booking cũ giữ giá khi thợ sửa giá; đổi lịch giữ giá;
  - trigger ghi `startingPrice` và `weekendFrom`;
  - CLI `holidays` ghi đúng năm.
- **Rules** (viết, CI chạy):
  - `validService` nhận `dayPrices` đủ 7 khoá, từ chối 6 khoá và giá 0;
  - `special_days` chỉ chủ ghi, khoảng > 60 ngày bị từ chối;
  - `holidays` không client nào ghi.
- **Flutter**:
  - S08.08 (bật/tắt, sắp thứ tự, trống);
  - S08.09 (chuyển hai mức ↔ từng thứ, điền sẵn, xem trước, lỗi);
  - S08.10 (thêm/sửa/xoá khoảng ngày);
  - S04.01–S04.03 hiện giá đúng ngày;
  - S08.01 bước 2 dùng S08.09;
  - kiểm tra ở 320 dp, cỡ chữ 1,3×, giao diện tối và sáng.

## 7. Chi phí Google

- Đặt lịch: thêm 2 lượt đọc (một tài liệu `holidays/{năm}`, truy vấn `special_days` của thợ, thường ≤ 3 tài liệu).
- S04.02: thêm 2 lượt đọc khi mở lịch.
- S08.10: ≤ 22 lượt đọc.
- Trigger gói: không đổi số lần chạy.
- Ước tính dưới **+$0,1/tháng** ở 10.000 MAU.

## 8. Ngoài phạm vi

- Giá theo khung giờ trong ngày.
- Giá theo phần trăm.
- Thu thêm hoặc hoàn chênh lệch khi đổi lịch.
- Giá theo ngày cho dịch vụ đi kèm, gói chia suất, Chụp ngay và báo giá.
- Màn gói của studio trên web (S28.06, #169) sẽ dùng cùng mô hình giá khi #169 được làm.
- Màn staff cho ngày lễ trên web (S23); Phase 1 dùng CLI.

## 9. Câu hỏi còn mở (đã có mặc định)

| Câu hỏi | Mặc định |
|---|---|
| Giá ngày đặc biệt chỉ áp cho ngày lễ chung, hay thợ tắt được từng ngày lễ? | Áp cho mọi ngày lễ chung. Thợ không muốn thì để trống giá đặc biệt, hoặc nghỉ ngày đó. |
| Ngày lễ chung có tính ngày nghỉ bù không? | Staff nhập đúng những ngày được nghỉ của năm đó, gồm cả nghỉ bù. |
| Có cần chặn giá cuối tuần thấp hơn ngày thường? | Không chặn. |
