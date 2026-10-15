# Điểm chụp đang hot (S29)

Ngày: 2026-10-08 · Trạng thái: thiết kế đã chốt với chủ dự án (brainstorm 2026-10-08) · Dựa trên: `2026-10-08-booking-addons-design.md` (dịch vụ đi kèm, mã S04.06), `2026-10-06-payments-payouts-design.md` (trả 100% trước, giữ, nhả hai mốc), `2026-10-06-studio-members-design.md` (S26), `2026-10-05-provider-types-portfolio-jobs-design.md`, spec chính `2026-10-01-remaining-screens.md` (sự kiện S11–S12, vị trí gần đúng, recommender), plan `2026-10-07-s04-booking-payment.md` (`buildBookingDraft`).

## 1. Mục tiêu

Có những nơi đang "hot" để chụp ảnh (đồi chè mùa sương, phố cổ, cánh đồng lúa chín). App đề xuất các điểm này. Người dùng mở một điểm và thấy: các thợ/studio nhận chụp tại đó vào những ngày cụ thể (thường là cuối tuần), gói chụp chia suất tại điểm, các sự kiện ở đó, và ảnh đã chụp ở đó. Từ đây khách đặt lịch như bình thường, kèm dịch vụ đi kèm của spec B.

## 2. Quyết định đã chốt

| # | Quyết định | Nguồn |
|---|---|---|
| T1 | **Độ hot kết hợp**: staff tạo danh sách điểm; hệ thống tự xếp hạng theo hoạt động gần đây; staff ghim hoặc ẩn. Tự động hoàn toàn để **Phase 2**. | chủ dự án 2026-10-08 (phương án C) |
| T2 | Thợ/studio nhận chụp tại điểm bằng **lịch tại điểm** (đặt gói thường, ngày và giờ bị giới hạn), và tuỳ chọn **gói chia suất tại điểm**. | chủ dự án (C) |
| T3 | **Gắn với điểm**: lịch tại điểm và sự kiện bắt buộc chọn (sự kiện được chọn "Không thuộc điểm chụp nào"); bài đăng được gợi ý điểm gần nhất, bỏ được; độ hot chỉ đếm những gì đã gắn. | chủ dự án (C) |
| T4 | **Mùa đẹp tuỳ chọn**: trong mùa ×1,5 điểm và nhãn "Đang vào mùa"; ngoài mùa không lên danh sách hot (trừ khi ghim), trang vẫn mở được. | chủ dự án (B) |
| T5 | **Ngày tại điểm**: ngày nằm trong lịch tại điểm cho phép **nhiều booking không chồng giờ** (cách nhau ≥ 15 phút), **chỉ tại điểm đó**; không nhận booking thường ở nơi khác ngày đó. | chủ dự án (phần 3) |
| T6 | Gói chia suất **không có dịch vụ đi kèm** ở Phase 1. Gói thường đặt tại điểm vẫn có (spec B). | chủ dự án |
| T7 | Staff quản lý điểm bằng **CLI** ở Phase 1 (`npm run spots`); màn staff trên web để #161/S23. | chủ dự án |
| T8 | Mã use case **S29** (S28 đang được #161 đề xuất cho studio trên web). | chủ dự án |
| T9 | Luật tiền, hoàn huỷ, liên hệ sau thanh toán, bàn giao hai lớp, chỉ nhà cung cấp đã duyệt mới nhận đơn: **giữ nguyên**. | CLAUDE.md |
| T10 | Phí vào cửa, chủ quản lý điểm, thợ tại điểm (miễn vé) và vé vào cửa bán qua app: spec riêng `2026-10-12-spot-organizer-entry-tickets-design.md` (S30, #223). | chủ dự án 2026-10-12 |

## 3. Điểm chụp và độ hot

### 3.1 `spots/{spotId}` (ULID; chỉ server ghi)

| Trường | Ghi chú |
|---|---|
| `name` | 3–60 ký tự, ví dụ "Đồi chè Cầu Đất" |
| `city`, `areaCode` | Mã khu vực trong taxonomy (như S02.05) |
| `point`, `geohash`, `radiusM` | Tâm và bán kính 100–3.000 m; dùng để gợi ý điểm gần nhất. Điểm chụp là nơi công khai, không phạm luật vị trí gần đúng. |
| `cover`, `description`, `tips[]` | Ảnh bìa (Storage `spots/{spotId}/cover.jpg`, nén theo `ImagePurpose` của S10); mô tả ≤ 600 ký tự; tối đa 5 mẹo, mỗi mẹo ≤ 120 ký tự |
| `seasonMonths` | Danh sách tháng 1–12; rỗng = đẹp quanh năm |
| `pinned`, `hidden` | Staff ghim lên đầu / ẩn khỏi danh sách hot |
| `status` | `active` \| `archived` (archived: không gợi ý, không nhận lịch mới; trang vẫn mở cho link cũ) |
| `hotScore`, `stats` | Server tính: `{posts14d, events, bookings14d, openSchedules}` |
| `createdAt`, `updatedAt`, `rankedAt` | UTC |

### 3.2 Xếp hạng (job `rankSpots`, mỗi ngày 03:00 giờ Việt Nam)

- `hotScore = 1 × posts14d + 3 × events + 2 × bookings14d + 2 × openSchedules`, trong đó `events` = sự kiện `open`/`full` sắp diễn ra trong 30 ngày, `bookings14d` = booking đã thanh toán gắn điểm trong 14 ngày qua, `openSchedules` = lịch tại điểm đang mở có ngày trong 30 ngày tới. Trong mùa: × 1,5.
- Dùng truy vấn đếm (`count()`), không đọc từng tài liệu.
- **Danh sách hot** của một khu vực: điểm `pinned` (không ẩn, `active`) trước, rồi tối đa 10 điểm `hotScore > 0`, không ẩn, `active`, đang trong mùa hoặc không có mùa, sắp theo `hotScore`. Thiếu thì bổ sung từ toàn quốc. Job ghi kết quả vào `spot_rankings/{areaCode}` và `spot_rankings/all` (mỗi tài liệu ≤ 20 điểm, kèm tên, ảnh bìa, thành phố, nhãn mùa, số thợ tuần này) để Trang chủ chỉ đọc **một** tài liệu.
- Điểm không được cập nhật hằng ngày khi chưa có job chạy (emulator): CLI có lệnh `npm run spots -- rank` chạy tay.

### 3.3 Staff (CLI, Phase 1)

`npm run spots -- add|edit|pin|unpin|hide|unhide|archive|rank|list` trong `app_flutter/firebase/functions` (giống `npm run awards`); chỉ chạy với Admin SDK trên emulator hoặc với tài khoản staff. Seed emulator: 5 điểm mẫu (Đồi chè Cầu Đất – Đà Lạt, mùa 10–12; Phố cổ Hội An, quanh năm; Hồ Tây – Hà Nội, quanh năm; Cầu Vàng – Đà Nẵng, quanh năm; Mù Cang Chải – Yên Bái, mùa 9–10).

## 4. Phía khách

### 4.1 Lối vào

- **S02.01 Trang chủ:** khu "Điểm chụp đang hot" cuộn ngang (đọc `spot_rankings/{areaCode}`): thẻ ảnh bìa, tên, thành phố, nhãn "Đang vào mùa" nếu có, "{n} thợ nhận chụp tuần này"; "Xem tất cả" → S29.01. Không có điểm: khu không hiện.
- **S02.03 Khám phá:** tab "Địa điểm" thành lưới điểm chụp (hot trước, rồi theo khoảng cách).
- **S02.04 Gần bạn:** hàng "Điểm chụp gần bạn" phía trên danh sách sự kiện.

### 4.2 S29.01 · Điểm chụp (`/spots`)

Chip lọc: khu vực, "Đang vào mùa", "Cuối tuần này có thợ". Thẻ lớn: ảnh bìa, tên, thành phố, mùa đẹp, "{n} thợ · {m} sự kiện sắp tới". Thứ tự: ghim → hot → còn lại theo khoảng cách. Phân trang 20. Trống: "Chưa có điểm chụp nào ở khu vực này".

### 4.3 S29.02 · Trang điểm chụp (`/spots/:spotId`)

Từ trên xuống:
1. Ảnh bìa, tên (Fraunces), thành phố; nhãn "Đang vào mùa · tới cuối tháng {m}" hoặc dòng "Mùa đẹp: tháng 10–11"; nút chia sẻ.
2. Mô tả, các mẹo chụp, bản đồ nhỏ tĩnh + "Chỉ đường" (mở app bản đồ của máy).
3. **Thợ nhận chụp ở đây**: chip ngày (Hôm nay · các ngày có lịch trong 14 ngày tới · Chọn ngày). Thẻ thợ: tên + dấu loại, "Có mặt {thứ} {ngày} · {giờ}–{giờ}", giá từ, % cà chua, "Hồ sơ" (viền) và "Đặt" (nút nhỏ).
4. **Gói chụp tại điểm**: thẻ gói chia suất ("Chụp sương sớm 30 phút · 490.000₫ · còn 4 suất CN 18/10"), nút "Chọn suất".
5. **Sự kiện ở đây**: `EventCard` sắp diễn ra.
6. **Ảnh chụp ở đây**: masonry bài gắn điểm (mới nhất, 20 mỗi trang), chạm → S02.02.

Không có nút gradient lớn; nút nhỏ trên thẻ được phép như `PhotographerCard`. Trống ngày đó: "Chưa có thợ nhận chụp ngày này · Xem ngày khác". Không có gì sắp tới: chỉ ảnh và mô tả, kèm dòng "Bạn là thợ ảnh? Thêm lịch chụp ở điểm này trong Công việc." (chỉ hiện với nhà cung cấp). Điểm `archived`: dải "Điểm này không còn nhận lịch mới".

### 4.4 Đặt lịch từ trang điểm

- **"Đặt" trên thẻ thợ** → luồng S04 có ngữ cảnh điểm: S04.01 chỉ các gói được bật cho lịch (kèm dịch vụ đi kèm, spec B); S04.02 chỉ ngày thuộc lịch (chọn sẵn ngày đang xem), giờ chỉ trong khung và bỏ giờ đã có người (đọc `spot_days`); S04.06 khoá địa điểm là điểm chụp (vẫn có "Điểm đón" nếu chọn xe); S04.03 có dòng "Tại {tên điểm}".
- **"Chọn suất"** → **S29.06** (sheet): chip ngày, lưới suất (giờ bắt đầu; suất kín mờ kèm chữ "Đã kín"), nút "Tiếp tục · {giá}" → thẳng S04.03.
- Booking lưu `spotId`, `source = spot | spot_slot`, `slotOfferId?`. Mọi đường vẫn qua `buildBookingDraft` + `assertOrderAllowed`.

## 5. Phía thợ/studio

### 5.1 `spot_schedules/{id}` (chỉ server ghi; công khai khi `open`)

`providerId`, `spotId`, `days: LocalDate[]` (≤ 60 ngày tới, tối đa 40 ngày), `window: {start, end}` (giờ địa phương, 05:00–21:00, dài 1–12 giờ), `serviceIds` (rỗng = mọi gói đang bật), `status: open | cancelled`, `createdAt`, `updatedAt`. Tối đa **8 lịch `open`** mỗi nhà cung cấp. Chỉ nhà cung cấp `acceptsOrders` mới tạo được (lỗi `not_accepting_orders`).

### 5.2 `spot_slot_offers/{id}`

`providerId`, `scheduleId`, `spotId`, `name` (3–60), `price` (VND, > 0), `slotMinutes` (15–90), `gapMinutes` (0–30), `photoCount`, `editedCount`, `deliveryDays`, `status: open | closed`. Suất = chia `window` của lịch thành `[start, start + slotMinutes]` cách nhau `slotMinutes + gapMinutes`. Tối đa 2 gói chia suất mỗi lịch.

### 5.3 Ngày tại điểm (T5)

- Thêm trạng thái `spot` vào `AvailabilityDay` (`{photographerId, day, state: 'spot', scheduleId}`), do server ghi khi lịch mở.
- Ngày `spot`: chỉ nhận booking `source = spot | spot_slot` của đúng lịch đó; nhiều booking, không chồng giờ, cách nhau ≥ 15 phút (suất của gói chia suất đã có khoảng nghỉ riêng). Booking thường cho ngày đó: lỗi `day_conflict`.
- Không mở lịch cho ngày đã `booked`/`pending`/`off` (lỗi `day_conflict`, liệt kê ngày trùng); không đặt được booking thường vào ngày `spot`.
- `spot_days/{scheduleId}_{day}`: bản công khai `{taken: [{start, end}]}` (không có thông tin khách), server ghi trong cùng transaction với booking. Transaction khoá theo `{providerId, day}`; hai khách đặt cùng giờ: người sau nhận `slot_taken`.
- Studio: lịch thuộc studio; ngày tại điểm áp dụng cho thợ được giao (S26: mỗi thợ một điểm một ngày). Giao thợ đã có booking nơi khác ngày đó: lỗi như S26.
- Huỷ lịch, hoặc bỏ một ngày khỏi lịch, khi còn booking ngày đó: chặn, báo "Còn {n} booking ngày {ngày}. Liên hệ khách hoặc huỷ từng booking (khách được hoàn 100%)." Thợ huỷ booking: khách hoàn 100% (luật hiện có).

### 5.4 Màn (lối vào: Công việc → "Lịch tại điểm", và từ trang điểm)

- **S29.03 · Lịch tại điểm của tôi** (`/me/spot-schedules`): danh sách lịch (điểm, ngày, khung giờ, số booking theo ngày, gói chia suất), "Huỷ lịch" chữ đỏ → sheet xác nhận nút đỏ. Nút chính "Thêm lịch tại điểm". Trống: "Chưa có lịch tại điểm" / "Chọn một điểm chụp đang hot và mở lịch cuối tuần để khách đặt."
- **S29.04 · Thêm/sửa lịch tại điểm**: chọn điểm (tìm theo tên, gợi ý điểm trong khu vực phục vụ, điểm đang hot trước), ngày (segmented "Lặp lại" — chọn thứ + từ ngày tới ngày — / "Chọn ngày"), khung giờ, gói đặt được, xem trước "12 ngày · 06:00–11:00", ngày trùng hiện đỏ kèm lý do. Nút chính "Mở lịch". Ngoài mùa của điểm: dòng nhắc "Điểm này đẹp nhất tháng 10–11".
- **S29.05 · Gói chia suất** (sheet): tên, giá, thời lượng suất, nghỉ giữa suất, số ảnh, số ngày giao, xem trước "8 suất/ngày: 06:00, 06:40 …". Nút "Lưu".

## 6. Gắn sự kiện và bài đăng (T3)

- **S12.01 (tạo sự kiện):** ô "Điểm chụp" bắt buộc: gợi ý các điểm `active` có vị trí sự kiện nằm trong bán kính, và lựa chọn "Không thuộc điểm chụp nào". Lưu `Event.spotId?`. Sửa sự kiện đổi được điểm.
- **S10.01 (đăng bài):** địa điểm bài nằm trong bán kính một điểm → chip "Gắn với {tên điểm} ×", bỏ bằng một chạm. Lưu `Post.spotId?`. Bài ẩn, bị gỡ do báo cáo (S20) hoặc đang chờ duyệt không hiện ở trang điểm và không được tính.
- Booking: `spotId` gắn khi đặt từ trang điểm (§4.4).

## 7. Server

- **Domain (`packages/domain`):** `spot_score.ts` (`spotHotScore`, `inSeason`, `rankSpots`), `spot_slots.ts` (`slotsFor(window, slotMinutes, gapMinutes)`), `spot_schedule.ts` (validate ngày/khung giờ/giới hạn, `dayConflicts`), `spot_booking.ts` (`assertSpotBooking`: ngày thuộc lịch, giờ trong khung, không chồng, khoảng cách 15 phút; chặn booking thường vào ngày `spot`).
- **Callables (`asia-southeast1`):** `saveSpotSchedule`, `cancelSpotSchedule`, `saveSlotOffer`, `closeSlotOffer`; đường tạo booking theo gói nhận `spotScheduleId?`, `slotOfferId?`. Lỗi mới: `outside_schedule`, `slot_taken`, `day_conflict`, `schedule_limit`, `spot_archived`.
- **Job:** `rankSpots` mỗi ngày (job định kỳ thứ 10).
- **Rules:** `spots`, `spot_rankings`, `spot_schedules` (`open`), `spot_slot_offers` (`open`), `spot_days`: ai cũng đọc; chỉ server ghi. Test rules viết kèm, CI chạy.
- **Index:** `spots(areaCode, status, hotScore desc)`, `spot_schedules(spotId, status)`, `spot_schedules(providerId, status)`, `posts(spotId, createdAt desc)`, `events(spotId, status, startAt)`, `bookings(spotId, paidAt)` (job đếm).

## 8. Mã màn và mock

| Mã | Màn | Loại |
|---|---|---|
| S29.01 | Điểm chụp (danh sách) | mới |
| S29.02 | Trang điểm chụp (+ `-empty` ngày không có thợ, `-offseason` ngoài mùa) | mới |
| S29.03 | Lịch tại điểm của tôi | mới |
| S29.04 | Thêm/sửa lịch tại điểm | mới |
| S29.05 | Gói chia suất (sheet) | mới |
| S29.06 | Chọn suất (sheet, phía khách) | mới |
| S02.01-spots | Trang chủ, khu "Điểm chụp đang hot" | biến thể |
| S02.03-spots | Khám phá, tab Địa điểm là điểm chụp | biến thể |
| S04.02-spot | Ngày và giờ giới hạn theo lịch tại điểm | biến thể |
| S12.01-spot | Tạo sự kiện, ô Điểm chụp | biến thể |
| S10.01-spot | Đăng bài, chip gắn điểm | biến thể |

S06.01 chỉ thêm một dòng lối vào "Lịch tại điểm" (không cần frame riêng). Đồng bộ: `docs/design/ui-mock.html`, bảng mã §2, `lib/core/screen_codes.dart`, `specs/screens/` (file mới `spots.md`).

## 9. Test

- **Domain:** công thức điểm, nhân mùa, mùa vắt qua năm (tháng 12–1); xếp hạng (ghim, ẩn, ngoài mùa, archived, bổ sung toàn quốc); chia suất (khung không chia hết, nghỉ 0); lịch: quá 60 ngày, khung ngoài 05:00–21:00, giới hạn 8, ngày trùng; booking: ngoài lịch, ngoài khung, chồng giờ, cách nhau < 15 phút, booking thường vào ngày `spot`.
- **Functions:** hai khách đặt cùng suất song song → một `slot_taken`; mở lịch trùng ngày đã có booking → `day_conflict`; huỷ lịch còn khách → bị chặn; `rankSpots` ghi `spot_rankings`; nhà cung cấp chưa nhận đơn bị chặn.
- **Rules (viết, CI chạy):** chỉ server ghi mọi collection mới; `spot_days` không chứa thông tin khách.
- **Flutter:** khu Trang chủ (một lần đọc), S29.01 lọc, S29.02 (chip ngày, các khối, trống, ngoài mùa, archived), S29.06 suất kín, luồng S04 từ điểm (gói/ngày/giờ bị giới hạn, địa điểm khoá), S29.03–S29.05 (giới hạn, ngày trùng đỏ, xem trước suất), S12.01 và S10.01 gắn điểm; 320 dp, chữ 1,3×, tối và sáng.

## 10. Chi phí Google (đơn giá `2026-10-07-google-cloud-costs.md`, Firestore cận trên $0,06/100K đọc)

- Trang chủ: 1 lượt đọc `spot_rankings` mỗi lần mở.
- Trang điểm: ≈ 50–60 lượt đọc (điểm, ≤ 20 lịch, gói chia suất, `spot_days` các ngày đang xem, ≤ 10 sự kiện, 20 bài).
- Job `rankSpots`: ≈ 4 truy vấn đếm × số điểm (≈ 200) + ghi `spot_rankings` ≈ 1.000 lượt đọc/ngày ≈ 30.000/tháng. Scheduler: job thứ 10, +$0,10/tháng.
- Đặt lịch tại điểm: thêm 1–2 lượt đọc/ghi `spot_days` mỗi booking.
- Ước tính: **(b) 1.000 MAU ≈ +$0,3/tháng; (c) 10.000 MAU ≈ +$2,1/tháng** (giả sử 5 lần mở trang điểm/người/tháng). Dưới ngưỡng $5.

## 11. Phase 2 (issue riêng)

- Độ hot tự động hoàn toàn: recommender xếp hạng điểm, cá nhân hoá theo người dùng, phát hiện điểm mới từ cụm bài đăng (không cần staff tạo).
- Lưu/theo dõi điểm chụp (S19) và thông báo "điểm bạn lưu vừa vào mùa / có thợ mới cuối tuần này" (S17).
- Gói chia suất có dịch vụ đi kèm; bản đồ tương tác trên trang điểm.
- Bản đồ mật độ check-in (điểm càng nhiều check-in càng đậm) và timeline check-in của mỗi người dùng tại các điểm chụp (#213, chủ dự án 2026-10-09). Check-in = bài hoặc bàn giao đã gắn điểm, không lưu toạ độ thô. Vẽ bằng lớp heatmap có sẵn của `maplibre_gl` (dự phòng `Heatmap` của `google_maps_flutter` ≥ 2.8), server đếm sẵn theo điểm và ô geohash.

## 12. Câu hỏi còn mở (đã có mặc định)

| Câu hỏi | Mặc định |
|---|---|
| Khoảng cách tối thiểu giữa hai booking trong ngày tại điểm | 15 phút |
| Ngày tại điểm của thợ có chặn nhận "Chụp ngay" (S13–S14)? | có, trong khung giờ của lịch |
| Khách thấy lịch tại điểm của thợ chưa xác minh? | không (chỉ `acceptsOrders`) |
