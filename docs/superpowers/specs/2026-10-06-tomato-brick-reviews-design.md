# Đánh giá bằng cà chua và gạch

Ngày: 2026-10-06 · Trạng thái: chờ duyệt · Thay cho: đánh giá 1–5 sao (spec gốc `2026-09-30-photography-marketplace-design.md` §review, spec chính `2026-10-01-remaining-screens.md`, màn S05.05 trong `screens/account.md`).

## 1. Vì sao đổi

Sao 1–5 có ba vấn đề với sản phẩm này:

- **Lạm phát**: gần như ai cũng 4,8–5★, khách không phân biệt được thợ tốt.
- **Thiếu bản sắc**: sao giống mọi app khác.
- **Chê nặng nề**: một sao trông như một hình phạt, khách ngại chê, thợ khó nhận góp ý.

Thay bằng hai phe, mượn tiếng lóng mạng: **🍅 cà chua = hài lòng**, **🧱 gạch = không hài lòng** (ném gạch là chê). Khách bấm liên tục vào phe mình chọn để nói mức độ.

## 2. Quyết định đã chốt

| # | Quyết định |
|---|---|
| D1 | Cà chua = hài lòng, gạch = không hài lòng. |
| D2 | Một lượt đánh giá chỉ chọn **một phe**. |
| D3 | Khách bấm nhiều lần (hit), **tối đa 10**. Số hit quy ra hệ số tăng nhanh ở vài hit đầu rồi chậm dần. |
| D4 | Con số công khai là **% cà chua** (tỷ lệ lượt hài lòng), kiểu Rotten Tomatoes. Hệ số hit dùng để xếp hạng và hiện trong từng review. |
| D5 | Gạch **công khai** như cà chua, nhưng bắt buộc chọn ít nhất một lý do. |
| D6 | Server tính hệ số và thống kê (`packages/domain`); app chỉ gửi phe và số hit. |
| D7 | Không chuyển đổi dữ liệu sao: chưa có project production, dữ liệu dev được seed lại. |

## 3. Mô hình dữ liệu

### 3.1 Một lượt đánh giá

`reviews/{bookingId}` (Firestore) / bảng `reviews` (SQL). Một đánh giá cho **mỗi đối tượng** trong một booking (booking studio có hai: thợ và studio, xem `2026-10-06-studio-members-design.md` §6), chỉ ghi qua callable `submitReview`; rules không đổi (client không được ghi).

| Trường | Kiểu | Quy tắc |
|---|---|---|
| `verdict` | `'tomato'` \| `'brick'` | thay cho `rating` |
| `hits` | số nguyên | 1–10 |
| `intensity` | số thực | server tính từ `hits` (§4.1), app không gửi |
| `reasons` | danh sách mã lý do | `brick`: ≥ 1 mã, không trùng; `tomato`: rỗng |
| `text` | chuỗi | giữ quy tắc cũ: 10–1000 ký tự (đếm grapheme) |
| `photos`, `photoPostId`, `customerId`, `photographerId`, `serviceId`, `createdAt`, `countedAt` | | giữ nguyên |

Bỏ trường `rating`.

Mã lý do gạch (chuỗi cố định, nhãn trong `app_vi.arb`):

| Mã | Nhãn |
|---|---|
| `late` | Đến trễ |
| `not_as_portfolio` | Ảnh không như mẫu |
| `slow_delivery` | Giao ảnh chậm |
| `attitude` | Thái độ |
| `price_changed` | Đổi giá |
| `other` | Khác |

Chọn `other` thì nội dung phải nói rõ lý do; không có trường riêng cho việc này, quy tắc 10 ký tự là đủ.

### 3.2 Thống kê của thợ

`stats` trên hồ sơ thợ (Firestore) / cột của `photographers` (SQL):

| Trường | Ý nghĩa |
|---|---|
| `reviewCount` | tổng lượt đánh giá đã đếm |
| `tomatoCount`, `brickCount` | số lượt mỗi phe |
| `signedSum` | tổng `+intensity` (cà chua) và `−intensity` (gạch) |
| `tomatoPct` | `round(100 · tomatoCount / reviewCount)`, số nguyên 0–100; 0 khi chưa có đánh giá |
| `score` | `signedSum / reviewCount`, làm tròn 3 chữ số, khoảng −1…+1; 0 khi chưa có đánh giá |

Bỏ `ratingSum`, `rating` (Firestore) và `rating_avg` (SQL).

## 4. Luật nghiệp vụ (`packages/domain`)

### 4.1 Hệ số

```
intensityOf(hits) = round2(0.4 + 0.6 · log10(hits)),  hits ∈ 1..10
```

| hits | 1 | 2 | 3 | 5 | 7 | 10 |
|---|---|---|---|---|---|---|
| intensity | 0,40 | 0,58 | 0,69 | 0,82 | 0,91 | 1,00 |

Hằng số đặt trong `review.ts`: `REVIEW_HITS_MAX = 10`, `INTENSITY_FLOOR = 0.4`.

### 4.2 Kiểm tra đầu vào

`validateReviewInput` thay `rating` bằng `verdict`, `hits`, `reasons`. Lỗi `invalid_argument` khi:

- `verdict` không phải `tomato`/`brick`;
- `hits` không phải số nguyên 1–10;
- `brick` mà `reasons` rỗng, có mã lạ hoặc trùng; `tomato` mà `reasons` không rỗng;
- các lỗi cũ (booking id, nội dung, ảnh) giữ nguyên.

`intensity` gửi từ app (nếu có) bị bỏ qua; server luôn tự tính.

### 4.3 Cộng thống kê

`addVerdict(current, verdict, intensity)` thay `addRating`, cùng cách phòng thủ với dữ liệu hỏng (trường thiếu hoặc sai kiểu coi như 0). `countReview` giữ nguyên cấu trúc transaction và cờ `countedAt`, nên một review chỉ được cộng một lần.

## 5. Màn S05.05 · Đánh giá và chia sẻ

Mã màn, route `/b/:id/review`, điểm vào và ra giữ nguyên. Đánh giá mở khi booking `approved`, tức lúc khách đồng ý ảnh mẫu và link ảnh gốc mở (`2026-10-06-delivery-preview-unlock-design.md`). Booking studio có hai khối đánh giá (spec Studio §6).

### 5.1 Bố cục (từ trên xuống)

1. Back + "Buổi chụp thế nào?"; `BookingCard` thu gọn.
2. **`VerdictPad`**: hai nút lớn cạnh nhau, 🍅 **"Hài lòng"** (trái) và 🧱 **"Chưa hài lòng"** (phải). Biểu tượng là SVG riêng trong `assets/` (Material Symbols không có cà chua và gạch). Màu từ hai token mới `tomato` và `brick` trong `design-system/tokens.json`, chỉ dùng cho hai biểu tượng này và thanh tỷ lệ (§6.2); phần còn lại giữ tỷ lệ 60‑30‑10 hiện có.
3. **Thanh mức độ** dưới hai nút, nhãn theo số hit:

   | Hit | 🍅 | 🧱 |
   |---|---|---|
   | 1–2 | Ổn | Hơi tiếc |
   | 3–5 | Hài lòng | Chưa ưng |
   | 6–9 | Rất hài lòng | Thất vọng |
   | 10 | Tuyệt vời! | Rất thất vọng |

4. Khi phe là 🧱: **nhóm chip lý do** (chọn nhiều, ít nhất 1), theo bảng §3.1.
5. Ô nhận xét (bắt buộc, 10–1000 ký tự). Gợi ý theo phe: 🍅 "Điều bạn thích nhất ở buổi chụp"; 🧱 "Kể rõ điều chưa ổn để thợ cải thiện".
6. Section "Chia sẻ ảnh bạn thích" giữ nguyên.
7. Thanh dưới giữ nguyên: "Chỉ đánh giá" và nút chính "Gửi & chia sẻ {n} ảnh".

### 5.2 Tương tác

- Mỗi chạm vào phe đang chọn = +1 hit: biểu tượng nảy nhẹ, nút hiện "×n", rung nhẹ (`HapticFeedback.lightImpact`). Hit thứ 10 rung mạnh hơn, nút ở trạng thái "đầy"; chạm thêm không đổi gì.
- Chạm sang phe kia: phe đang có hit về 0, phe mới bắt đầu ở 1 hit, không hỏi xác nhận. Chip lý do đã chọn được giữ trong phiên nếu khách quay lại phe gạch.
- Có hit thì hiện nút chữ **"Làm lại"** để về trạng thái chưa chọn phe.
- Hit cộng dồn, không giới hạn thời gian giữa hai lần chạm (không có combo hết giờ).
- Hiệu ứng chỉ chạy khi chạm, không có animation lặp nền (quy tắc pin `docs/testing/battery-and-performance.md`).

### 5.3 Trợ năng

Mỗi nút là một điều khiển chỉnh được: nhãn đọc "Ném cà chua, 3 trên 10" / "Ném gạch, 2 trên 10", có hành động tăng và giảm cho trình đọc màn hình. Nhờ vậy người không bấm nhanh được vẫn đặt được số hit. Vùng chạm ≥ 48 dp.

### 5.4 Trạng thái

- Nút gửi vô hiệu khi: chưa chọn phe; nhận xét chưa đủ 10 ký tự; phe gạch mà chưa có lý do. Một dòng nhỏ dưới nút nói thiếu gì.
- Booking chưa `completed` → chặn như cũ.
- Đã đánh giá → chế độ xem lại: phe, "×n", lý do, nội dung, ảnh; không sửa.
- Gửi lỗi → giữ nguyên lựa chọn và nội dung, hiện lỗi qua SnackBar như các form khác.

### 5.5 Chuỗi mới (`app_vi.arb`)

`reviewTomato` "Hài lòng", `reviewBrick` "Chưa hài lòng", `reviewHits` "×{n}", `reviewTomatoLevel1..4`, `reviewBrickLevel1..4` (theo bảng §5.1), `reviewReset` "Làm lại", `reviewReasonsTitle` "Điều gì chưa ổn?", `reviewReason_late`, `reviewReason_not_as_portfolio`, `reviewReason_slow_delivery`, `reviewReason_attitude`, `reviewReason_price_changed`, `reviewReason_other`, `reviewTextHintTomato`, `reviewTextHintBrick`, `reviewNeedVerdict` "Chọn cà chua hoặc gạch", `reviewNeedReason` "Chọn ít nhất một lý do", `reviewA11yTomato` "Ném cà chua, {n} trên 10", `reviewA11yBrick` "Ném gạch, {n} trên 10". Giữ các khoá `s12_*` hiện có.

### 5.6 Phân tích

`review_submit{verdict, hits, reasons, shared}` thay `review_submit{rating, shared}`.

## 6. Hiển thị

### 6.1 Con số tổng hợp

| Số đánh giá | Hiển thị |
|---|---|
| 0 | ẩn (như hiện nay) |
| 1–4 | "Mới · {n} đánh giá" |
| ≥ 5 | "🍅 {tomatoPct}% · …" |

Ngưỡng 5 là hằng số `TOMATO_PCT_MIN_REVIEWS` trong `packages/domain` và một hằng tương ứng trong app.

Áp dụng ở:

- `PhotographerCard` và các dòng meta ở Trang chủ, Tìm, chi tiết ảnh: "★ 4.9 · 112 buổi" → "🍅 94% · 112 buổi".
- Header hồ sơ thợ: ô "4.9 ★★★★★ / 58 đánh giá" → "94% 🍅 / 58 đánh giá".
- `formatRating` → `formatTomatoPct`; `PhotographerSummary.ratingAvg`/`hasRating` → `tomatoPct`, `score`, `tomatoCount`, `brickCount`, `hasTomatoPct` (≥ 5 đánh giá).

### 6.2 Danh sách review trên hồ sơ

- Đầu danh sách: thanh tỷ lệ hai màu (`tomato`/`brick`) và "{tomatoCount} 🍅 · {brickCount} 🧱".
- Mỗi review: **`VerdictBadge`** (biểu tượng phe + "×n"), chip lý do nếu là gạch, rồi nội dung và ảnh như cũ.
- Gạch nằm cùng thứ tự thời gian với cà chua, không bị ẩn hay đẩy xuống.

## 7. Xếp hạng, bộ lọc, huy hiệu, thông báo

### 7.1 Recommender (`local_recommender.dart`)

```
smoothedScore(p) = (v · score + m · C) / (v + m),  v = reviewCount, m = 10, C = 0.6
```

- `C = 0.6` tương đương mức tiên nghiệm cũ 4,3★ trên thang mới.
- `smoothedRating` → `smoothedScore`; `_quality` dùng `smoothedScore` trực tiếp (bỏ phép quy đổi `(r − 3)/2`), vẫn cộng phần thưởng theo số buổi và kẹp về 0…1.
- Sắp xếp "Đánh giá" (Tìm, báo giá S16) dùng `smoothedScore`.
- Lý do gợi ý "đánh giá cao": `reviewCount ≥ 10` và `tomatoPct ≥ 95`, chuỗi `reasonTopRated` → "🍅 {pct}% từ {n} đánh giá".

### 7.2 Bộ lọc màn Tìm

Chip "★ 4.5+" → "🍅 90%+", lựa chọn 80% / 90% / 95%. `FindFilters.minRating` → `minTomatoPct` (int). Thợ dưới 5 đánh giá không qua bộ lọc này.

### 7.3 Huy hiệu

Spec chính §huy hiệu, nguồn `review`: "Được đánh giá cao" đổi từ "≥ 4,8 sao và ≥ 20 đánh giá" thành **"≥ 95% cà chua và ≥ 20 đánh giá"**. Các huy hiệu khác không đổi. Huy hiệu chưa được cài (hook `awardBadgesAfterReview` đang rỗng), nên chỉ sửa spec.

### 7.4 Thông báo cho thợ (S17)

Hai loại mới trong danh mục thông báo, gửi khi `onReviewWrite` đếm xong review:

| Loại | Nội dung | Mở |
|---|---|---|
| `review_tomato` | "Bạn nhận 🍅 ×{n} từ buổi chụp {ngày}" | review đó trên hồ sơ |
| `review_brick` | "Có góp ý mới về buổi chụp {ngày}" | review đó trên hồ sơ |

Nếu kênh gửi thông báo phía server chưa có khi làm plan này, chỉ thêm hai loại vào danh mục và để lại hook, giống cách `awardBadgesAfterReview` đang làm.

## 8. Backend tự host và hợp đồng API

- `services/api`: **migration mới** (không sửa migration cũ): bảng `photographers` bỏ `rating_avg`, thêm `tomato_count`, `brick_count`, `signed_sum`, `tomato_pct`, `score`; bảng `reviews` bỏ `rating`, thêm `verdict` (check `in ('tomato','brick')`), `hits` (check 1–10), `intensity`, `reasons text[]` (check: `brick` có ≥ 1, `tomato` rỗng). Cập nhật `migrations.test.ts`.
- `services/dispatch/api/openapi.yaml`: `PhotographerCard.rating` → `tomatoPct` (integer, nullable) và `reviewCount`.
- `docs/superpowers/specs/data-model/`: `domain-model.md` (`Review`, `PhotographerStats`, kiểu `Verdict`, `ReviewReason`) và `relational-schema.md` (hai bảng trên, bảng nguồn của cột tính).

## 9. Mock, gallery và spec liên quan

**Đã làm cùng spec này** (cùng nhánh):

- `docs/design/ui-mock.html`: token `--tomato`/`--brick` (tối và sáng), biểu tượng `i-tomato`/`i-brick`; S05.05 dùng `VerdictPad` (cà chua ×7); thêm `S05.05-brick` (gạch ×3 kèm chip lý do) và `S03.01-reviews` (tab Đánh giá: % cà chua, thanh tỷ lệ, `VerdictBadge`); mọi chỗ "★ 4.x" ở thẻ, hồ sơ, Tìm, chip lọc, sự kiện, đặt nhanh và báo giá đổi sang "🍅 n%" (Thu Hà ở S02.06 minh hoạ "Mới · 3 đánh giá"); huy hiệu "Được đánh giá cao" ở S03.02 đổi theo §7.3.
- Spec cũ sửa theo spec này: `screens/account.md` (S05.05), `screens/discovery.md` (S02.02, S03.01, S02.06), `screens/jobs.md` (S16), `components/shared-components.md` (`PhotographerCard`), spec chính 2026-10-01 (huy hiệu, dự phòng xếp hạng, S02.06), spec gốc 2026-09-30 (`stats`, `Review`), spec đặt nhanh 2026-10-01 (thành phần `rating` của điểm điều phối = `(score + 1)/2`), `data-model/domain-model.md`, `data-model/relational-schema.md`.

**Còn lại cho plan** (đơn vị 4): thêm `VerdictPad` và `VerdictBadge` vào `components/shared-components.md` và gallery `docs/design/ui-components.html` (sinh bằng `scripts/tools/build_ui_components.py`). Widget `StarRating` trong code (`features/review/widgets/star_rating.dart`) bị xoá ở đơn vị 3.

**Plan chưa chạy còn nhắc sao**: instant I2–I5 (`RUN-ORDER.md` dòng 10–13, vốn phải viết lại theo spec đặt nhanh mới) và plan 16 (pin/hiệu năng). Khi viết lại hoặc chạy các plan này, dùng `tomatoPct`/`score` thay `rating`. Plan và ledger đã chạy là lịch sử, không sửa.

Mã màn không đổi; `lib/core/screen_codes.dart` không đổi.

## 10. Kiểm thử

- **Domain** (`packages/domain`): `intensityOf` với 1, 3, 10 và các giá trị ngoài khoảng; `validateReviewInput` với mọi lỗi ở §4.2; `addVerdict` với thống kê rỗng, hỏng, nhiều lượt hỗn hợp (kiểm `tomatoPct`, `score`, làm tròn); `countReview` không cộng hai lần.
- **Functions**: `submitReview` ghi đủ trường mới và tự tính `intensity`; `onReviewWrite` cập nhật `stats`; test tích hợp emulator theo mẫu hiện có.
- **SQL**: `migrations.test.ts` kiểm các ràng buộc check.
- **Flutter**:
  - `VerdictPad`: chạm cộng hit, trần 10, chuyển phe về 1, "Làm lại", hành động trợ năng tăng/giảm, nhãn mức độ.
  - S05.05: điều kiện bật nút gửi; gạch bắt buộc lý do; chế độ xem lại.
  - `formatTomatoPct` và ngưỡng 5 đánh giá; `smoothedScore` (ít review không thắng nhiều review); bộ lọc `minTomatoPct`.
  - Golden cho `VerdictPad` (đã chọn cà chua ×3, gạch ×10) và `VerdictBadge`, gắn tag `golden` như các golden khác.
- **Seed**: dữ liệu emulator (`firebase/functions/seed`) và `FakeContentRepositories` dùng review cà chua/gạch, có thợ dưới 5 đánh giá và thợ nhiều gạch để thấy đủ trạng thái.

## 11. Ngoài phạm vi

- Đánh giá theo nhiều tiêu chí, hoặc cà chua và gạch trong cùng một lượt.
- Thợ trả lời review, khiếu nại review, kiểm duyệt nội dung (S18/S20 lo).
- Khách sửa hay xoá review sau khi gửi.
- Thống kê "lý do gạch thường gặp" trên hồ sơ (cần thêm bộ đếm theo lý do; làm sau nếu cần).
- Chuyển đổi dữ liệu sao thật (chưa có production).

## 12. Chia việc

Một plan, bốn đơn vị chạy theo thứ tự (đơn vị sau dựa vào trường dữ liệu của đơn vị trước):

1. **Domain + Functions + SQL**: §3, §4, §7.4 (danh mục và hook), §8; seed emulator.
2. **Data + xếp hạng Flutter**: model review, `PhotographerSummary`, repository Firestore và fake, `local_recommender`, `FindFilters`, `formatTomatoPct`.
3. **UI Flutter**: token và biểu tượng, `VerdictPad`, `VerdictBadge`, S05.05, thẻ, header và danh sách review trên hồ sơ, chip lọc; chuỗi và golden.
4. **Gallery + widget docs**: phần "còn lại" của §9.
