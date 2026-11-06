# Ledger: S08 chuỗi giá theo ngày và lịch âm (#316, làm lại 2026-11-06)

Plan: `docs/superpowers/plans/2026-11-06-s08-day-pricing-series.md`. Spec: `docs/superpowers/specs/2026-11-06-day-pricing-redesign.md`. Thay `ledger-day-pricing.md` (giá theo thứ và ngày đặc biệt của PR #326, đã gỡ hết).

Đơn vị chạy trên hai repo, cùng tên nhánh `plan/316-day-pricing-series`:

- **booking-be** [PR #5](https://github.com/thanhngochoang/booking-be/pull/5), merge trước. Gồm Task B1–B5: lịch âm, domain chuỗi giá, `createBooking` tính giá theo ngày, callable và adapter, rules, job hằng ngày, công cụ dọn dữ liệu cũ, seed.
- **booking**: PR này. Gồm Task A1–A9: `lib/core/lunar.dart`, `AppCalendar` và hai date picker, bản Dart của domain, S08.08–S08.10, S03.01 và S04.01–S04.03, đổi 16 màn có lịch sang `AppCalendar`, gỡ code giá v1.

## Hiện có gì

- **Gói** `photographers/{uid}/services/{id}`: chỉ còn `price` (giá thường) và `order`. `validService` và domain từ chối `dayPrices`, `specialPrice`, `priceMode`, `occasionPrices`.
- **Chuỗi giá** `photographers/{uid}/price_rules/{id}`: `serviceId`, `price`, `name?`, `repeat` (`none` | `weekly` | `yearly`), `lunar?`, `from`, `to`, `weekdays?`, `start?`, `until?`, `exceptions?`, `template?`, `createdAt`, `updatedAt`. Chỉ server ghi qua bốn callable `savePriceRule`, `splitPriceRule`, `setPriceRuleException`, `deletePriceRule`; rules từ chối mọi ghi từ client, kể cả của chủ.
- **Trường chỉ server** `endsOn` (`yyyy-MM-dd`): ngày cuối chuỗi còn áp (`to` với `none`, `until` nếu có, lấy ngày nhỏ hơn). Store ghi ở mọi lần ghi, chỉ job hằng ngày đọc. Không nằm trong `PriceRule` của domain và không có trong bảng Postgres đích (job SQL tự tính được).
- **Một luật, hai bản.** `priceForDay`, `startingPrice`, `splitRule`, `withException`, `scaledRule` ở booking-be `packages/domain/src/day_pricing.ts`; bản Dart ở `app_flutter/lib/data/pricing/price_rules.dart`. Âm lịch (Hồ Ngọc Đức, +7) ở `lunar.ts` và `app_flutter/lib/core/lunar.dart`. Cùng bảng ca; bản của app là `app_flutter/test/data/contracts/day_pricing_cases.json`, copy từ booking-be `packages/domain/test/fixtures/day_pricing_cases.json`, copy lại mỗi khi luật đổi. `lib/data/pricing/day_pricing.dart` chỉ còn `Weekday`, `weekdayOf`, `kMaxPriceVnd`.
- **Booking** giữ `serviceSnapshot.price` (giá ngày), thêm `priceKind` (`base` | `rule`) và `ruleName?` do server ghi. Đổi lịch giữ giá.
- **`priceSummary`** của thợ: `startingPrice` và `hasDayPricing`, tính bằng `refreshPriceSummary` ở trigger gói, trigger `price_rules` và job `expirePriceRules` mỗi ngày. `weekendFrom`, `hasSpecialPrices`, `holidays/{year}`, `special_days`, CLI `holidays`, `SEED_HOLIDAYS` đã bỏ.
- **Dữ liệu v1 trên staging**: app ghi `FieldValue.delete()` cho bốn trường cũ ở mọi lần ghi gói; script `firebase/functions/tools/cleanup_day_pricing_v1.ts` ở booking-be (chạy tay) xoá `holidays`, `special_days`, `weekendFrom`. Chạy xong thì `npm run stats -- recompute --only price`. Deploy BE và app cùng lúc trên staging.
- Đường `/me/special-days` còn lại chỉ là redirect sang `/me/day-pricing`.

## Rulings

**Thứ tự làm và đặt tên**
- B2 đặt API mới ở file mới `price_rules.ts`; B3 xoá API cũ và đổi tên thành `day_pricing.ts` (giữ `Weekday`, `WEEKDAYS`, `weekdayOf`, `MAX_PRICE`), export ở `index.ts`. Mọi commit đều build được, không trùng tên.
- Bản Dart nằm ở `lib/data/pricing/price_rules.dart` như plan; spec ghi `day_pricing.dart`, file này chỉ giữ `Weekday`.
- A1 tách A1a (`lib/core/lunar.dart`, chỉ cần B1), A1b (`price_rules.dart` và bảng ca, cần B2) và A1c (làm sau A4: bảng ca mới, tie-break theo id, fake split/edit). Task app và task booking-be chạy song song vì khác repo; không bao giờ hai người làm trong cùng một repo.
- Giữ `AvailabilityCalendar` cho S04.02 đến khi A7 đưa số âm vào mọi lịch (cùng PR).

**Lịch âm và ngày**
- Tết 2030 là 2030-02-02 (trăng mới 23:09 ngày 2/2 theo +7; 3/2 là ngày theo +8). `lunar.py` tham chiếu khớp; spec, plan và brief đã sửa. `solarToLunar` TS khớp `lunar.py` trên 2020-01-01..2040-12-31 (7671 ngày, 0 lệch).
- Ngày trong Dart là UTC midnight (`DateTime.utc(y, m, d)`, như `calendarDay`, `monthOf`), không phải giờ máy như plan ghi. Mọi task Dart dùng `calendarDay` và `parseDayKey`.
- Không có bộ chọn ngày âm riêng: `from`/`to` của chuỗi âm lịch lấy từ ngày dương đã chọn (spec §5.4).
- Ngày thuộc tháng nhuận bị cắt khỏi khoảng âm lịch; ngày âm 30 kẹp về cuối tháng; chuỗi dương `02-29` bị từ chối (sheet phải báo lỗi).

**Domain và giá**
- Giới hạn là mã lỗi mới `rule_limit` và `exception_limit` trong `ERROR_CODES` (như `addon_limit`), không phải `failed_precondition` kèm field. Callable trả `HttpsError` `failed-precondition` với `details.code` = mã đó; app đọc `details.code`.
- Sửa cả chuỗi giữ `template` cũ khi input không có.
- Sửa cả chuỗi bỏ các ngoại lệ mà quy tắc mới không còn phủ (như Google Calendar); plan nói "giữ ngoại lệ" là hiểu "còn hợp lệ".
- `splitPriceRule` mà phần `before` không còn lần nào từ hôm nay (`nextOccurrence(before, today) == null`) thì thay hoặc xoá cả chuỗi, để chuỗi chết không dồn lên giới hạn 30. Booking đã chụp giá, ngày quá khứ không đặt được. Hệ quả chấp nhận: `priceForDay` của ngày quá khứ trong chuỗi đó theo giá mới.
- Cùng bậc cùng giá: chuỗi có id nhỏ nhất (từ điển) thắng, ở TS và Dart, để tên chuỗi ở S04.02 luôn bằng `ruleName` của snapshot bất kể thứ tự đầu vào. Bảng ca có thêm ca này.
- `name` được trim, `''` thành thiếu, và qua cùng kiểm tra lộ liên hệ như tên dịch vụ đi kèm (số điện thoại, email, link bị từ chối).
- Chọn cho cổng khám phá (B3): `PriceRuleReader` (`rulesForService`, `rulesForProvider`) dùng lại cho `DiscoveryDeps.priceRules` và `SpotScheduleDeps.priceRules`, không viết port riêng. `createBooking` đọc ngoài giao dịch như đọc gói.
- Job `expirePriceRules` hỏi `endsOn` trong [hôm nay − 7, hôm qua] và chạy lại `refreshPriceSummary` (idempotent), nên bỏ lỡ vài lượt chạy vẫn bắt kịp; ghi log cảnh báo khi dùng đường bắt kịp.
- `startingPrice` có thể thấp khi các ngoại lệ `null` xoá hết ngày còn lại của chuỗi rẻ.
- Mọi lần app ghi gói (lưu, bật/tắt, batch `order`) gửi thêm `FieldValue.delete()` cho `dayPrices`, `specialPrice`, `priceMode`, `occasionPrices`, vì `validService` `hasOnly` làm hỏng cập nhật từng phần trên gói v1. Rules test có ca "gói cũ chỉ bỏ được các trường này" và ca "cập nhật thiếu một trường thì lỗi".
- Tên mẫu trong `priceRuleTemplates` giữ tiếng Việt trong lớp data: đó là giá trị ghi vào `name` của chuỗi và khớp hằng số server, không phải chữ giao diện.

**Calendar và picker**
- `AppCalendar` cao ô ≥ 44 dp (vùng chạm); chiều rộng theo màn (7 × 44 + lề 32 dp không vừa 320 dp).
- `AppCalendar.onRangeCompleted` (chạm thứ hai, chạm đôi cùng ngày, hoặc kết thúc kéo); `onRangeChanged` giữ cho phản hồi tức thì. Picker khoảng chỉ bật "Chọn" sau khi hoàn thành. Chạm đầu phát khoảng `d..d`.
- Một khoảng không chứa ngày bị `disabledDay`: ngày cuối bị cắt về ngày trước ngày tắt đầu tiên sau ngày bắt đầu.
- Cách kéo: `AppCalendar` có **cả hai**, giữ rồi kéo (long-press) và chạm hai ngày (picker dùng chạm hai ngày). Riêng S08.10 chạm một ngày mở sheet nên chọn khoảng chỉ bằng giữ rồi kéo.
- Tiêu đề tháng mọi lịch là "Tháng {m} / {y}" (spec §5.3), thay "Tháng {m}, {y}" của các màn dùng `AvailabilityCalendar`. Khoá `calendarMonthTitle`, `calendarDaySemantics` đã xoá.
- `showAppDatePicker` có `disabledDay`, và không bao giờ trả `initial` bị tắt hoặc ngoài first..last: "Chọn" tắt đến khi chọn ngày dùng được (có test).
- Rút gọn tên chuỗi ở ô S04.02: cả tên nếu vừa, không thì từ đầu tiên. Chuỗi hằng tuần không hiện tên dưới ngày (chỉ giá rút gọn, "1,8M" dưới mọi T7). Chuỗi khác: tên ghi ở **ngày đầu tiên còn hiện giá** của mỗi đoạn liền (sau khi bỏ ngày đã qua, đã đặt, không rảnh), nên đoạn bắt đầu từ ngày đã qua vẫn có tên.

**S08.08–S08.10**
- Dòng "Giá theo ngày" của S08.08 khi chưa tải được hoặc tải lỗi chỉ hiện tiêu đề, không ghi "Chưa có chuỗi" (không khẳng định điều chưa biết).
- S08.10: ô có ngoại lệ đọc thêm "ngoại lệ" (qua `dayStyle.spoken`), vì viền màu chỉ là màu. Sau "Bỏ ngày này khỏi chuỗi" SnackBar nói "Đã bỏ ngày khỏi chuỗi", sau "Kết thúc chuỗi từ ngày này" nói "Đã kết thúc chuỗi" (không phải "Đã lưu giá").
- Kiểm khoảng cục bộ của chuỗi hằng năm âm lịch giữ nguyên `from`/`to` đã lưu (sửa, mẫu) không đo theo số ngày dương đang hiện (khoảng chạy qua tháng nhuận dài hơn): bỏ kiểm đó, `validatePriceRuleField` đo bằng ngày âm đã lưu (tháng 30 ngày) như `validatePriceRule` của server.
- S08.08 ở chế độ sắp xếp không có công tắc (spec "công tắc ẩn" là ẩn công tắc, như mock; plan hiểu nhầm là có).
- Hàng chuỗi trong thẻ S08.10: hằng tuần trước, rồi theo lần tới gần nhất. Chuỗi không còn lần tới hiện ở nhóm "Đã kết thúc" (thu gọn, mờ; mở sheet sửa kèm "Xoá chuỗi"); chúng vẫn tính vào giới hạn 30 phía server (reader đọc tối đa 30 tài liệu).
- Chạm một ngày ở S08.10 mở sheet của **chuỗi thắng ngày đó**: điền sẵn, "Lưu" cả ba radio và chữ đỏ (bỏ ngày / kết thúc / xoá) đều ghi vào chuỗi thắng, kèm dòng "{khác} … bị {thắng} thay" như cũ. Chỉ khi không chuỗi nào thắng (ngày đã bị bỏ khỏi chuỗi) sheet mới mở trên chuỗi giữ ngoại lệ (id nhỏ nhất nếu có nhiều). Ngoại lệ không bị kẹt dưới chuỗi không đặt giá: mỗi chuỗi của gói giữ ngoại lệ ở ngày đó có một hành động "Về giá chuỗi" (`setException(clear)`); của chuỗi đang mở giữ nhãn "Về giá chuỗi", của chuỗi khác ghi tên ("Về giá chuỗi Cuối tuần"). Nhiều chuỗi cùng giữ ngoại lệ thì hiện đủ từng cái, xếp theo id.
- S08.10-day điền sẵn giá theo radio: giá ngày cho "Chỉ ngày này" và "và các ngày sau", giá chuỗi cho "Cả chuỗi". "Chỉ ngày này" với đúng giá hiện tại thì không ghi gì (tránh ghi đè chuỗi bằng một ngoại lệ).
- "Bỏ ngày này khỏi chuỗi" và "Kết thúc chuỗi từ ngày này" qua sheet xác nhận đỏ như "Xoá chuỗi".
- Lỗi lưu của sheet "Đặt giá" và sheet một ngày hiện ngay trên nút "Lưu" (SnackBar nằm sau sheet). `contact_leak` ở `name` hiện dòng "Tên không được chứa số điện thoại hay đường link" dưới ô tên.
- "Áp cho" ẩn khi thợ chỉ có một gói; nút "Đặt giá" ở danh sách mở sheet cho gói đang bật đầu tiên.
- S08.10 ẩn khỏi thẻ chuỗi mọi chuỗi không còn lần tới (không chỉ chuỗi `none` đã qua); chúng chỉ hiện ở nhóm "Đã kết thúc" của danh sách.

**Đặt lịch, S05.02**
- Không đổi chi tiết booking: không màn nào hiện `serviceSnapshot.price` hôm nay (S05.02 không có dòng giá). `snapshotPriceReason` sẵn sàng khi có; "(Tết)" sẽ hiện ở mọi chỗ hiện giá của snapshot.
- Luồng đặt lắng nghe provider chuỗi giá của cả thợ (S04.01 cần chuỗi mọi gói, một listener).

## Deferred

**Việc theo sau (đã báo trong PR)**
- `SpotSchedule.priceFrom` đóng băng lúc lưu lịch.
- `endsOn` chỉ gần đúng khi có ngoại lệ rẻ đã qua hoặc `until` sau lần xuất hiện cuối. Ngoại lệ giá rẻ đã qua trên chuỗi hằng tuần/hằng năm không kết thúc giữ `startingPrice` thấp đến lần ghi tiếp theo (spec §4.5 chỉ nói chuỗi `none` hết hạn).
- Booking nhận ngày `2026-02-31` (`isDateString` sẵn có).
- S28.06 (studio web, #169) cần cùng mô hình chuỗi giá.
- Lọc và sắp xếp S02.06 theo đúng giá của ngày đã chọn (spec §8).
- Chưa kiểm trên thiết bị; test widget phủ 320 dp ở chữ 1,3× sáng và tối.

**Minor còn lại, theo task**
- B1: công thức tháng nhuận 12 trả 0 (sao từ amlich; không có nhuận 12 trong 2020–2040); `parseDay` nhận `2025-02-31`; `lunarToSolar`, `lunarMonthLength` không kiểm khoảng; thiếu test ngày sai dạng.
- A1a: thứ tự export `core.dart`; vài ca `solarToLunar` cố định ngoài Tết; `lunarMonthLength` tháng nhuận trong năm không nhuận chưa test.
- B2: khoảng dương hằng năm tính tháng 2 là 29 ngày (trần 92 ngày hơi chặt); năm âm ngoài khoảng hỗ trợ thì ném lỗi; khoá ngoại lệ `__proto__` (lý thuyết).
- A3: kéo ra ngoài lưới hoặc mép chưa mô tả; ngữ nghĩa khoảng thiếu đầu/cuối; chữ âm lịch 7sp cho người nhìn kém; màu trắng, 7, 8.5 cứng; picker cần `today`; `_dayAt` gắn với hình học.
- B3: test lệch dòng trong `create_booking.test.ts`; thiếu test store bộ nhớ cho throw-after-put; `applyToAll` đọc giá gốc ngoài giao dịch (cần comment); split trước lần xuất hiện đầu của chuỗi chưa bắt đầu để lại `before` chết.
- A1b: `toMap` bỏ ngoại lệ rỗng; thứ tự khoá `withException`; vài lệch với rule dựng tay (không tới được từ dữ liệu `tryParse`).
- A1c: comment của fake dài quá 80 cột; test chuỗi chết của fake dựa vào "hôm nay" mặc định.
- B4: công cụ dọn hỏng cả batch nếu một tài liệu biến mất (chạy lại được); thêm một lần đọc cho blind put.
- B5: thiếu test rules cho đường lưu chính xác của app với `updateDoc` + `deleteField`; context `dp6` không có tài liệu user (vô hại).
- A2: thứ tự lỗi của fake (`not_found` trước kiểm giá); fake chỉ kiểm input; thiếu test hai khoá service dùng chung một listener; `invalid_response` sau ghi thành công hiện là `unknown`.
- A4: lỗi field `to`/`from` của server map sang dòng cố định; mã `template` còn sau khi sửa ngày tay; lệch mock (số âm "(âm lịch)" ở hàng danh sách, nhãn trên dropdown, icon thêm ở cuối, dòng giá 8px cứng, hậu tố ₫ cứng).
- A5: chỉ hiện chuỗi hằng tuần đầu tiên; tên chuỗi hằng tuần hạ chữ đầu; tải chuỗi lỗi thì lặng lẽ bỏ phần phụ; `update` ghi lại `deliverables` (sẵn có).
- A6: stream lỗi sau khi có giá trị giữ danh sách cũ; S04.03 không có nút thử lại sau khi đọc lại lỗi; sheet S03.01 chỉ hiện "Giá thường" khi đang tải hoặc lỗi; `snapshotPriceReason` chưa dùng.
- A7: test "hết chỗ" mất phần khớp semantics đầy đủ; chấm sự kiện đổi cỡ.
- A8: `quote_sheet` dự phòng dùng `calendarDay(clock())` thay `vnToday`; `job_post_sheets` chưa có dấu hôm nay; chưa có test mới cho các nơi gọi đã đổi.
