# Giá theo ngày, làm lại: chuỗi giá lặp lại như Google Calendar và lịch âm dùng chung (S08.08–S08.10)

Ngày: 2026-11-06 · Trạng thái: chủ dự án đã duyệt UI 2026-11-06, spec chờ duyệt · Issue: #316 (mở lại 2026-11-06) · Thay thế: `2026-11-04-day-pricing-design.md` (PR #319, làm ở PR #326). Phần nào spec này không nhắc tới thì giữ như spec cũ và mã đã merge.

## 1. Vì sao làm lại

Chủ dự án mở lại #316 sau PR #326: UX quá tệ (form gói trộn hai chế độ giá, công tắc giá đặc biệt, dải xem trước; giá đặc biệt nằm trong gói còn ngày đặc biệt nằm màn khác; mỗi gói chỉ một giá đặc biệt) và ngày lễ bị fix cứng (seed 2026–2027, staff ghi tay từng năm bằng CLI, thợ chỉ xem).

Qua bốn vòng mock, chủ dự án chốt (2026-11-06):

- Trọng tâm là **gói** và giá gói **điều chỉnh theo ngày**; nhập liệu dễ, tính toán dễ.
- Nhập dạng **lặp lại, có ngoại lệ trong chuỗi, giống Google Calendar**: "Chỉ ngày này / Ngày này và về sau / Cả chuỗi".
- Lịch luôn hiện **ngày âm** là số nhỏ cùng hàng, sát chân số ngày dương; cho lặp theo **ngày âm hoặc ngày dương**.
- Lịch là **control dùng chung**, mọi màn có lịch dùng nó.
- Ít nút bấm: "Lặp lại" là một **switch**, bật mới hiện phần chuỗi (như Teams); chu kỳ là **dropdown**; dương/âm lịch là một **switch**; "Áp cho" là dropdown.

## 2. Ý tưởng chính

- Mỗi gói có **một giá thường** (`price`). Mọi giá khác là một **chuỗi giá** (`price_rules`) của gói đó: hằng tuần (T7, CN hay thứ tự chọn), hằng năm theo dương lịch, hằng năm theo âm lịch, hoặc một khoảng ngày lẻ. Một chuỗi có thể có **ngoại lệ** từng ngày (bỏ ngày đó khỏi chuỗi, hoặc giá riêng cho ngày đó) và **mốc kết thúc** (khi "ngày này và về sau" cắt chuỗi), đúng cách Google Calendar lưu sự kiện lặp.
- Thợ làm việc trên **lịch tháng**: thấy giá dưới từng ngày, chạm một ngày hoặc kéo chọn khoảng rồi đặt giá và chọn cách lặp. Ngày lễ, Tết là mẫu điền sẵn; âm lịch máy tự tính cho mọi năm. **Không còn `holidays/{year}`, không còn CLI, không còn dữ liệu theo năm.**
- Một hàm `priceForDay(service, rules, day)` dùng chung TS và Dart.
- `AppCalendar`: một control lịch trong `core/widgets`, luôn hiện ngày âm, thay cho `AvailabilityCalendar` và `showDatePicker` ở mọi màn.

## 3. Quyết định

| # | Quyết định | Nguồn |
|---|---|---|
| R1 | Gói chỉ còn `price` (giá thường). **Bỏ** `dayPrices`, `specialPrice`, `priceMode`, `holidays/{year}`, `special_days`, CLI `holidays`, seed ngày lễ. Thay thẳng, không có đường tương thích: PR #326 chỉ ở `develop`, chưa lên `main`, chưa có release. | chủ dự án; kiểm tra git 2026-11-06 |
| R2 | Mọi giá khác giá thường là một **chuỗi giá** `photographers/{uid}/price_rules/{id}` thuộc một gói, với `repeat` ∈ {`none`, `weekly`, `yearly`}, cờ `lunar` cho hằng năm theo âm lịch, ngoại lệ và mốc kết thúc như §4.1. | chủ dự án ("giống Google Calendar") |
| R3 | Giá một ngày: lấy các chuỗi của gói **chứa ngày đó** (sau khi áp ngoại lệ), xếp theo bậc **`none` > `yearly` > `weekly`**; bậc cao nhất thắng; cùng bậc lấy **giá cao nhất**; không có chuỗi nào → `price`. Ngoại lệ có giá riêng dùng giá đó ở bậc của chuỗi; ngoại lệ "bỏ ngày" làm chuỗi không chứa ngày đó. | thiết kế |
| R4 | Sửa một ngày đang thuộc chuỗi có ba lựa chọn: **Chỉ ngày này** (ghi ngoại lệ), **Ngày này và các ngày sau** (chuỗi cũ `until` = hôm trước, chuỗi mới `start` = ngày này, cùng quy tắc, giá mới), **Cả chuỗi** (đổi giá chuỗi). Xoá cũng ba lựa chọn tương ứng (bỏ ngày khỏi chuỗi / cắt chuỗi / xoá chuỗi). | chủ dự án |
| R5 | Âm lịch tính bằng thuật toán **Hồ Ngọc Đức** (múi giờ +7) ở cả TS và Dart, chung bảng ca. Ngày–tháng âm trong năm có tháng nhuận lấy **tháng chính**. Dịp âm qua năm (23/12 → 5/1) được phép. | thiết kế; đã kiểm tra Tết 2024–2033 |
| R6 | Lịch dùng chung `AppCalendar` luôn hiện ngày âm: **số nhỏ cùng hàng, sát chân số ngày dương** (mùng 1 ghi "1/M" màu nhấn). Có `showAppDatePicker` và `showAppDateRangePicker` thay `showDatePicker`/`showDateRangePicker` của Flutter. Mọi màn có lịch chuyển sang control này (§5.6). | chủ dự án |
| R7 | Sheet Đặt giá: switch **"Lặp lại"** tắt mặc định; bật mới hiện phần chuỗi thụt vào (như Microsoft Teams): dropdown **Chu kỳ** (Hằng tuần / Hằng năm) và switch **Theo âm lịch** (chỉ khi Hằng năm; Hằng tuần thay bằng hàng 7 ô tròn T2…CN). "Áp cho" là dropdown. Không có hàng chip, trừ chip mẫu khi sheet mở trống. | chủ dự án 2026-11-06 |
| R8 | "Áp cho: Mọi gói, cùng tỉ lệ" tạo một chuỗi giống hệt cho mỗi gói khác với giá = `price` của gói đó × (giá nhập ÷ `price` gói đang chọn), **làm tròn lên 10.000₫**. Sau đó các chuỗi độc lập nhau. | thiết kế |
| R9 | Booking chụp `serviceSnapshot.price`, thêm `priceKind` (`base` \| `rule`) và `ruleName?` do server ghi. Đổi lịch giữ giá. "Từ {giá}", bộ lọc, `SpotSchedule.priceFrom` lấy **min(`price`, giá mọi chuỗi còn lần tới)** của gói đang bật (bỏ chuỗi `none` đã qua và chuỗi đã hết `until`), cùng con số với cận dưới khoảng giá ở S03.01 và S04.01. | giữ P4–P6, sửa P6; builder check 2026-11-06 |
| R10 | Rules không kiểm được giá trị trong map có khoá tuỳ ý: `exceptions` chỉ kiểm là map ≤ 50 khoá; giá trị không hợp lệ (không phải int 1–10^9 và không phải null) bị domain **bỏ qua** (coi như không có ngoại lệ). App kiểm `validatePriceRule` trước khi ghi. | thiết kế |
| R11 | Mẫu dịp (Tết, Giỗ Tổ, 30/4 – 1/5, 2/9, Tết Dương lịch, Valentine, 8/3, Trung thu, 20/10, Noel, Mùa cưới) là **hằng số trong mã**, chỉ điền sẵn `name`, `repeat`, `from`, `to`; thợ sửa tự do. | thiết kế |
| R12 | Luật tiền, giữ tiền, hoàn huỷ, chỉ nhà cung cấp đã duyệt mới nhận đơn: giữ nguyên. | CLAUDE.md |
| R13 | **Không có bảng giá theo ngày tính sẵn.** Giá một ngày luôn tính bằng `priceForDay` lúc đọc, từ gói và các chuỗi của gói; không có trigger ghi `day_prices` hay map giá theo ngày lên tài liệu thợ. Bộ lọc ngân sách và sắp xếp "Giá" ở S02.06 vẫn dùng `startingPrice` ghi sẵn (R9); lọc đúng giá của ngày đã chọn ngoài phạm vi (§8). | chủ dự án 2026-11-06 ("tra luôn") |
| R14 | Tháng nhuận âm lịch: `solarToLunar` trả cờ `leap`; chuỗi hằng năm theo âm lịch chỉ khớp **tháng chính**, ngày thuộc tháng nhuận không bao giờ thuộc chuỗi. Khi thợ chọn khoảng ngày rơi vào tháng nhuận cho chuỗi âm lịch, sheet ghi `from`/`to` theo tháng chính cùng số và hiện dòng nhắc "Tháng {M} năm nay nhuận, chuỗi lặp theo tháng {M} chính". | thiết kế; chủ dự án hỏi 2026-11-06 |

## 4. Dữ liệu

### 4.1 Chuỗi giá · `photographers/{uid}/price_rules/{id}` (chủ ghi, người đăng nhập đọc)

| Trường | Kiểu | Ghi chú |
|---|---|---|
| `serviceId` | string | Gói của chuỗi. |
| `price` | int 1–1.000.000.000 | Giá trong chuỗi. |
| `name?` | string ≤ 40 | "Mùa cưới", "Tết Nguyên đán". Thiếu → app hiện "Giá riêng". |
| `repeat` | `none` \| `weekly` \| `yearly` | Switch "Lặp lại" tắt = `none`. |
| `lunar?` | bool | Chỉ `yearly`. `true` = `from`/`to` là ngày–tháng âm. Thiếu = `false`. |
| `from`, `to` | string | `none`: `yyyy-MM-dd`. `yearly`: `MM-dd` (dương, hoặc âm khi `lunar`; tháng chính). `weekly`: không có. `to` trước `from` khi hằng năm = qua năm. |
| `weekdays?` | list `mon`…`sun`, 1–7 phần tử | Chỉ `weekly`. |
| `start?`, `until?` | `yyyy-MM-dd` | Chuỗi chỉ có hiệu lực trong [`start`, `until`]. Thiếu = không giới hạn. "Ngày này và về sau" ghi hai trường này. |
| `exceptions?` | map `yyyy-MM-dd` → int \| null | ≤ 50 khoá. null = ngày bị bỏ khỏi chuỗi; int = giá riêng ngày đó. |
| `template?` | string | Mã mẫu đã dùng, để danh sách mẫu đánh dấu. |
| `createdAt`, `updatedAt` | timestamp | |

Ràng buộc (rules kiểm kiểu, độ dài, dạng chuỗi ngày; app và domain kiểm phần còn lại): `none`/`yearly` dài ≤ 92 ngày; `none`: `to ≥ from`, `to ≥ hôm nay` khi tạo, ≤ 730 ngày tới; `until ≥ start`; ≤ 30 chuỗi mỗi gói (app đếm); `serviceId` phải là gói của chủ.

### 4.2 Gói · `photographers/{uid}/services/{id}`

Chỉ còn `price` cho giá. `validService` **từ chối** `dayPrices`, `specialPrice`, `priceMode`, `occasionPrices`. `order` giữ như PR #326.

### 4.3 Mẫu (`PRICE_RULE_TEMPLATES`, hằng số TS và Dart)

| Mã | Tên | `repeat` · `lunar` | `from` → `to` | Nhóm |
|---|---|---|---|---|
| `tet` | Tết Nguyên đán | `yearly` · âm | 12-23 → 01-05 | Ngày lễ |
| `hung_kings` | Giỗ Tổ Hùng Vương | `yearly` · âm | 03-10 | Ngày lễ |
| `new_year` | Tết Dương lịch | `yearly` | 01-01 | Ngày lễ |
| `reunification` | 30/4 – 1/5 | `yearly` | 04-30 → 05-01 | Ngày lễ |
| `national_day` | Quốc khánh | `yearly` | 09-02 | Ngày lễ |
| `valentine` | Valentine | `yearly` | 02-14 | Dịp khác |
| `womens_day` | 8/3 | `yearly` | 03-08 | Dịp khác |
| `mid_autumn` | Trung thu | `yearly` · âm | 08-15 | Dịp khác |
| `vn_womens_day` | 20/10 | `yearly` | 10-20 | Dịp khác |
| `christmas` | Noel | `yearly` | 12-24 → 12-25 | Dịp khác |
| `wedding_season` | Mùa cưới | `yearly` | 10-15 → 12-31 | Dịp khác |

### 4.4 Domain (`packages/domain/src/day_pricing.ts` và `lunar.ts`; Dart `core/lunar.dart`, `data/pricing/day_pricing.dart`)

```ts
// lunar.ts
solarToLunar(day: LocalDate): { day; month; year; leap }
lunarToSolar(day, month, year, leap = false): LocalDate | null
lunarLabel(day: LocalDate): string            // "6", "1/10" ở mùng 1 (dùng cho ô lịch)

// day_pricing.ts
type Repeat = 'none' | 'weekly' | 'yearly'
interface PriceRule { id; serviceId; price; name?; repeat; lunar?: boolean; from?; to?; weekdays?; start?; until?; exceptions?: Record<string, unknown> }

ruleRanges(rule, year): { from: LocalDate; to: LocalDate }[]       // khoảng dương lịch của chuỗi trong năm (yearly: 1–2 khoảng, âm lịch quy ra dương; none: 0–1)
ruleCoversDay(rule, day): { covers: boolean; price?: number }       // đã áp start/until và exceptions
priceForDay(service, rules, day): { amount; kind: 'base' | 'rule'; rule?: PriceRule }
monthPrices(service, rules, year, month): Record<LocalDate, ReturnType<typeof priceForDay>>   // cho ô lịch
startingPrice(service, rules): number                                 // R9
splitRule(rule, day, newPrice): { before: PriceRule; after: PriceRule }   // "ngày này và về sau"
withException(rule, day, price: number | null): PriceRule
scaledRule(rule, fromService, toService): PriceRule                   // R8
validatePriceRule(rule, today, serviceIds): void                      // DomainError('invalid_argument', field)
PRICE_RULE_TEMPLATES
```

Bảng ca chung (`test/data/contracts/day_pricing_cases.json`): Tết (mùng 1) 2024-02-10, 2025-01-29, 2026-02-17, 2027-02-06, 2028-01-26, 2029-02-13, 2030-02-03, 2031-01-23, 2032-02-11, 2033-01-31; Giỗ Tổ 2025-04-07, 2026-04-26; 23 tháng Chạp trước Tết 2026 = 2026-02-10, mùng 5 = 2026-02-21; năm nhuận (2025 nhuận tháng 6) lấy tháng chính; dịp âm qua năm ra hai khoảng dương; `weekly` T7–CN; ngoại lệ bỏ ngày (rơi về chuỗi `weekly` nếu có) và ngoại lệ giá riêng; `start`/`until`; bậc `none` > `yearly` > `weekly`; cùng bậc lấy cao nhất; giá trị ngoại lệ không hợp lệ bị bỏ qua; `startingPrice` với chuỗi `weekly` rẻ hơn giá thường.

### 4.5 Đặt lịch và tóm tắt công khai

- `createBooking` đọc gói và `price_rules` có `serviceId` = gói (≤ 30 tài liệu) **trước giao dịch**, như cách đọc gói và `special_days` hiện nay (`SpecialDayReader` thành `PriceRuleReader`), tính `priceForDay`, so `expectedPrice` (khác → `price_changed` như cũ), rồi ghi `serviceSnapshot.price`, `priceKind`, `ruleName?` trong giao dịch. Thợ sửa chuỗi đúng lúc đó thì booking lấy giá khách vừa thấy; không đổi cấu trúc giao dịch.
- Trigger gói và trigger `price_rules` (mới, cùng hàm) tính `priceSummary` của thợ: `startingPrice` (R9), `hasDayPricing` (có chuỗi nào không); bỏ `weekendFrom`. Chuỗi `none` hết hạn làm `startingPrice` đổi mà không có lần ghi nào: job hằng ngày sẵn có (hoặc một job mới lúc 00:05) chạy lại `refreshPriceSummary` cho thợ có chuỗi vừa hết hạn. `SpotSchedule.priceFrom` dùng `startingPrice`.
- Rules: xoá `match /holidays` và `special_days`; thêm `price_rules` (chủ ghi, `signedIn()` đọc; kiểm `serviceId` string, `price` int 1–10^9, `repeat` trong 3 giá trị, `lunar` bool chỉ khi `yearly`, `from`/`to`/`start`/`until` đúng dạng theo `repeat`, `weekdays` list ≤ 7, `exceptions` map ≤ 50 khoá, `name` ≤ 40); `validService` chỉ nhận `price`.
- Functions: xoá `tools/holidays.ts`, script `holidays`, test; seed: bỏ `SEED_HOLIDAYS` và `special_days`, thêm cho thợ An ba chuỗi của gói chân dung: Cuối tuần (`weekly`, T7–CN, 1,8M), Mùa cưới (`yearly` 11-14 → 11-22, 2M, ngoại lệ 2026-11-15 = 1,5M), Tết (`yearly` + `lunar` 12-23 → 01-05, 2,5M).

### 4.6 Không phụ thuộc Firestore (để Phase 2 chuyển sang API Node.js + PostgreSQL)

Nguyên tắc: Firestore chỉ là **nơi lưu**, mọi phép tính nằm trong `packages/domain` (TS thuần, không import Firebase; API Fastify của Phase 2 import thẳng gói này) và bản Dart cùng bảng ca.

1. **Port thay adapter.** `SpecialDayReader` trong `booking_ports.ts` đổi thành `PriceRuleReader { rulesForService(providerId, serviceId): Promise<PriceRule[]> }`. Adapter Firestore ở `firebase/functions/src/infra`; Phase 2 viết adapter Kysely. `createBooking`, `startingPrice`, `monthPrices` chỉ nhận `ServiceRecord` và `PriceRule[]`, không biết nguồn dữ liệu.
2. **Kiểu dữ liệu chung cho cả hai nơi.** Ngày là chuỗi `yyyy-MM-dd` (không dùng `Timestamp`, tránh lệch múi giờ; PostgreSQL là `date`). Tiền là số nguyên VND (`bigint`). Id là chuỗi (`text`, như `services.id`). Ngày–tháng hằng năm là `MM-dd`. Âm lịch **tính bằng code, không lưu**, nên không có bảng âm lịch nào phải di trú.
3. **Không có dữ liệu suy ra phải đồng bộ** (R13). Thứ duy nhất ghi sẵn là `startingPrice`; nó được tính bằng một use case domain `refreshPriceSummary(providerId)`. Phase 1: trigger Firestore gọi use case này. Phase 2: gọi trong cùng giao dịch SQL khi lưu chuỗi, ghi vào cột `photographers.starting_price` đã có.
4. **Ghi qua use case, không ghi thẳng từ app** (đề xuất, xem §9). App gọi `PriceRuleRepository` với các lệnh `saveRule`, `deleteRule`, `splitRule` (ngày này và về sau), `setException`. Phase 1 adapter là callable; Phase 2 là HTTP tới Fastify. Kiểm tra nằm một chỗ (`validatePriceRule`), "ngày này và về sau" (sửa chuỗi cũ + tạo chuỗi mới) là một giao dịch ở cả hai nơi. Đọc vẫn có thể là truy vấn live Firestore ở Phase 1.
5. **Bảng đích PostgreSQL** (chỉ là đích ghi trong spec; #316 **không** thêm migration, OpenAPI hay `relational-schema.md`; Phase 2 làm khi chuyển dữ liệu; không sửa migration cũ):

```sql
create table price_rules (
  id              text primary key,
  photographer_id text not null references photographers(user_id) on delete cascade,
  service_id      text not null references services(id) on delete cascade,
  price           bigint not null check (price between 1 and 1000000000),
  name            text check (char_length(name) <= 40),
  repeat          text not null check (repeat in ('none','weekly','yearly')),
  lunar           boolean not null default false,
  from_date date, to_date date,                 -- repeat = none
  from_md text, to_md text,                     -- repeat = yearly, 'MM-dd'
  weekdays        smallint,                     -- repeat = weekly, bit 0 = Thứ 2 … bit 6 = CN
  start_date date, until_date date,
  template        text,
  created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
  check (lunar = false or repeat = 'yearly'),
  check ((repeat = 'none')   = (from_date is not null and to_date is not null)),
  check ((repeat = 'yearly') = (from_md is not null and to_md is not null)),
  check ((repeat = 'weekly') = (weekdays between 1 and 127))
);
create index ix_price_rules_service on price_rules (service_id);

create table price_rule_exceptions (
  rule_id text not null references price_rules(id) on delete cascade,
  day     date not null,
  price   bigint check (price between 1 and 1000000000),   -- null = bỏ ngày khỏi chuỗi
  primary key (rule_id, day)
);

alter table bookings add column price_kind text not null default 'base' check (price_kind in ('base','rule')),
                     add column rule_name text;
```

Map `exceptions` của Firestore thành bảng con; `weekdays` list thành bitmask. Script di trú đọc từng tài liệu `price_rules` và ghi một dòng cha cộng các dòng ngoại lệ; giá trị ngoại lệ không hợp lệ (R10) bị bỏ khi di trú.
6. **Test hợp đồng dùng lại.** `day_pricing_cases.json` chạy cho TS, Dart ở #316, và về sau cho một test của adapter Kysely ở Phase 2 (ghi ca vào PostgreSQL thật, đọc lại qua `PriceRuleReader`, so kết quả `priceForDay`).

## 5. Màn hình

Mã màn giữ S08.08, S08.09, S08.10. Mock: `docs/design/ui-mock.html` `#S08.08`, `#S08.08-sort`, `#S08.09`, `#S08.10`, `#S08.10-new`, `#S08.10-repeat`, `#S08.10-day`, `#S08.10-list`; biến thể `#S04.02-dayprice`, `#S03.01-prices`.

### 5.1 S08.08 · Gói dịch vụ (`/me/packages`)

1. Thanh tiêu đề "Gói dịch vụ"; bên phải "Sắp xếp" (≥ 2 gói).
2. Dòng "Giá theo ngày" (nền nhấn nhạt) tóm tắt chuỗi của mọi gói: "Cuối tuần, Tết, Mùa cưới · 5 chuỗi" (chưa có: "Cuối tuần và ngày lễ lấy bằng giá thường · Đặt giá") → S08.10.
3. "{n} gói đang bật · giá dưới là giá ngày thường".
4. Thẻ gói (chạm → S08.09): tên; "2 giờ · 40 ảnh chỉnh · giao 3 ngày"; giá thường đậm, rồi " · cuối tuần 1,8M · Tết 2,5M" (chuỗi `weekly` nếu có và chuỗi gần nhất sắp tới, tính bằng domain); công tắc bật/tắt. Không tay kéo. Gói tắt: mờ, chip "Đang ẩn".
5. Nút chính "Thêm gói" → S08.09.

Chế độ Sắp xếp (S08.08-sort): tiêu đề "Sắp xếp gói", "Xong"; mỗi thẻ có tay kéo và nút "Lên"/"Xuống" (mờ ở đầu/cuối), công tắc ẩn; "Xong" ghi `order` một batch. Trống và "tắt gói cuối cùng" như PR #326.

### 5.2 S08.09 · Thêm/sửa gói (`/me/packages/new`, `/me/packages/:id`, `?from=setup`)

1. Tên; thời lượng (chip 1/2/3/4/6/8 giờ); số ảnh chỉnh, giao sau (một hàng). Như cũ.
2. **Một ô "Giá ngày thường"** (bàn phím số).
3. Thẻ chỉ đọc (chỉ khi sửa và gói có chuỗi): mỗi chuỗi một dòng "Cuối tuần · T7, CN — 1.800.000₫", "Tết Nguyên đán · 23/12 – 5/1 âm lịch — 2.500.000₫", "Mùa cưới · 14/11 – 22/11 · 1 ngoại lệ — 2.000.000₫"; cuối thẻ link "Giá theo ngày" → S08.10 với gói này đang chọn. Thêm mới hoặc chưa có chuỗi: một dòng "Cuối tuần, ngày lễ: đặt ở Giá theo ngày sau khi lưu". Ẩn khi `?from=setup`.
4. Chữ phụ "Booking đã đặt giữ giá cũ."
5. Nút chính "Lưu gói"; khi sửa có chữ "Ẩn gói".

Lưu chỉ ghi `price` (và các trường gói khác). Lỗi dưới ô như cũ. Thoát khi có thay đổi chưa lưu → sheet "Bỏ thay đổi?".

### 5.3 S08.10 · Giá theo ngày (`/me/day-pricing?service=:id`)

1. Thanh tiêu đề "Giá theo ngày"; bên phải biểu tượng danh sách → S08.10-list.
2. Chip chọn gói "Chân dung · 1,5M", "Cặp đôi · 3,2M"… (gói đang bật trước, gói ẩn sau, mờ).
3. Điều hướng tháng (‹ Tháng 11 / 2026 ›).
4. **`AppCalendar`** tháng: mỗi ô = ngày dương, ngày âm nhỏ cùng hàng sát chân, dòng dưới là giá rút gọn ("1,5M"). Giá thường mờ; ngày thuộc chuỗi chữ đậm; khoảng đang chọn tô nhấn; ngày có ngoại lệ viền màu cảnh báo. Chú thích một dòng dưới lịch.
5. Thẻ "Chuỗi của gói": mỗi chuỗi một hàng (biểu tượng lặp hoặc sự kiện, tên, quy tắc "Hằng tuần · T7, CN" / "Hằng năm · 14/11 – 22/11 · 1 ngoại lệ" / "Hằng năm · 23/12 – 5/1 âm lịch", giá). Chạm → S08.10-new ở chế độ sửa cả chuỗi.
6. Nút chính "＋ Đặt giá" → S08.10-new với từ–tới = khoảng đang chọn (hoặc hôm nay).

Tương tác trên lịch: chạm một ngày → S08.10-day nếu ngày thuộc chuỗi, ngược lại S08.10-new với từ = tới = ngày đó. Kéo từ ngày đầu tới ngày cuối (hoặc chạm hai ngày liên tiếp) → chọn khoảng, rồi "Đặt giá".

### 5.4 S08.10-new · Sheet "Đặt giá" (tạo / sửa cả chuỗi)

Mặc định sheet chỉ có:
1. Ô "Giá · {tên gói}".
2. Hai ô "Từ", "Tới" (mở `showAppDatePicker`).
3. Switch **"Lặp lại"**, tắt. Tắt = một khoảng ngày lẻ (`repeat: none`).
4. Ô "Tên (tuỳ chọn)".
5. **Dropdown "Áp cho"**: "Chỉ gói {tên}" / "Mọi gói, cùng tỉ lệ" (R8). Chỉ khi tạo mới.
6. Nút "Lưu". Khi sửa: chữ đỏ "Xoá chuỗi" → xác nhận "Booking đã đặt giữ giá cũ".

Bật "Lặp lại" thì ngay dưới switch hiện phần chuỗi, thụt vào (S08.10-repeat):
- Dropdown **"Chu kỳ"**: "Hằng tuần" / "Hằng năm".
- Hằng năm: switch **"Theo âm lịch"** (tắt = theo ngày dương của từ–tới, dòng phụ "14/11 – 22/11 mỗi năm"; bật = theo ngày âm của từ–tới, dòng phụ "6/10 – 14/10 âm lịch mỗi năm · năm sau là T4 3/11 – T5 11/11/2027"; từ–tới rơi vào tháng nhuận thì thêm dòng nhắc R14).
- Hằng tuần: hàng 7 ô tròn T2 … CN thay cho switch âm lịch, điền sẵn các thứ nằm trong từ–tới; hai ô từ–tới ẩn đi.
- Tắt switch thì phần này thu lại; dữ liệu đã chọn giữ trong phiên.

Mở sheet từ nút "Đặt giá" khi chưa chọn ngày: hàng chip mẫu nhanh ở đầu sheet (Tết, Giỗ Tổ, 30/4 – 1/5, 2/9, Noel, Mùa cưới…; mẫu đã có bị mờ) điền sẵn tên, từ–tới, bật lặp lại và chu kỳ/âm lịch. Đây là nơi duy nhất còn chip, vì mẫu là lối tắt không bắt buộc.

Lỗi: "Giá phải lớn hơn 0", "Giá tối đa 1.000.000.000₫", "Khoảng tối đa 92 ngày", "Chỉ chọn từ hôm nay trở đi", "Chỉ chọn trong 2 năm tới", "Chọn ít nhất một thứ", "Gói này đã có 30 chuỗi".

### 5.5 S08.10-day · Sheet "Sửa một ngày trong chuỗi"

Tiêu đề "{Thứ} {ngày}" và tên gói. Dòng chuỗi đang áp ("Mùa cưới · 2.000.000₫ · Hằng năm · 14/11 – 22/11"); nếu ngày thuộc hai chuỗi: dòng phụ "Cuối tuần 1,8M bị Mùa cưới thay". Ô "Giá ngày này" điền sẵn giá hiện tại. Mục "Áp dụng cho" ba radio: **Chỉ ngày này** · **Ngày này và các ngày sau trong chuỗi** · **Cả chuỗi {tên}** (R4). Nút "Lưu". Chữ đỏ "Bỏ ngày này khỏi chuỗi" (với radio "cả chuỗi" thành "Xoá chuỗi"; với "và các ngày sau" thành "Kết thúc chuỗi từ ngày này").

### 5.6 S08.10-list · Chuỗi giá (`/me/day-pricing/rules`)

Nhóm theo gói ("Chân dung · giá thường 1,5M"), mỗi chuỗi một hàng như §5.3 mục 5, ngoại lệ liệt kê khi ≤ 2 ("CN 15/11: 1,5M"). Chuỗi `none` đã qua tự ẩn. Chạm → S08.10-new sửa. Biểu tượng lịch → về S08.10. Nút chính "＋ Đặt giá".

### 5.7 `AppCalendar` dùng chung (`core/widgets/app_calendar.dart`, `core/lunar.dart`)

- Lưới tháng 7 cột, tuần bắt đầu Thứ 2, ô ≥ 44 dp. Mỗi ô: số ngày dương; **ngày âm là số nhỏ cùng hàng, sát chân số dương** (mùng 1 ghi "1/M" màu nhấn); dòng phụ tuỳ màn (`dayBuilder`: giá, chấm bận, "Lễ"…). Ngày âm **luôn hiện**, không có cờ tắt.
- Chọn: `single`, `range` (chạm hai ngày hoặc kéo), `none`. Ngày không chọn được (`disabledDay`), ngày đánh dấu (`markers`).
- `showAppDatePicker(context, {initial, first, last})` và `showAppDateRangePicker(...)`: sheet có `AppCalendar`, nút "Chọn", thay cho `showDatePicker`/`showDateRangePicker` của Flutter.
- Thay ở mọi chỗ đang dùng lịch hoặc date picker: `core/widgets/availability_calendar.dart` (thành `AppCalendar` + `dayBuilder`), `features/booking/steps/datetime_step.dart` (S04.02), `features/calendar/my_calendar_screen.dart`, `features/chat/widgets/reschedule_sheet.dart`, `features/collab/collab_paid_sheet.dart`, `features/entry/entry_buy_screen.dart`, `features/event_create/create_event_screen.dart`, `features/event_manage/entry_days_tab.dart`, `features/find/find_sheets.dart`, `features/job_market/quote_sheet.dart`, `features/jobs/job_post_sheets.dart`, `features/organizer/entry_tickets_edit_screen.dart`, `features/organizer/widgets/resident_sheet.dart`, `features/photographer_profile/widgets/profile_sections.dart` (`CalendarSliver`), `features/spots/spot_schedule_edit_screen.dart`, `features/spots/spot_screen.dart`. `features/packages/special_day_sheet.dart` bị xoá.

### 5.8 Màn đã có

| Màn | Thay đổi so với PR #326 |
|---|---|
| S08.01 bước 2 | Vẫn dùng S08.09 (`?from=setup`), không có thẻ chuỗi. |
| S03.01 sheet bảng giá | Dòng "Giá thường {giá}", rồi mỗi chuỗi của gói một dòng "{tên} · {quy tắc} — {giá}". |
| S04.01 | Khoảng giá "1,5M–2,5M" = min/max của giá thường và các chuỗi của gói (không tính `none` đã qua). |
| S04.02 | `AppCalendar` (có ngày âm) với giá dưới ngày và tên chuỗi rút gọn ("Tết 2,5M") màu nhấn. Tiêu đề khi chọn ngày: "T3 17/2 · Tết · 2.500.000₫". Đọc `price_rules` của gói (một truy vấn). |
| S04.03, S09 | "(Tết)" từ `serviceSnapshot.ruleName`; "(giá theo ngày)" khi `priceKind = rule` không tên. |
| `PhotographerCard`, bộ lọc | "từ {startingPrice}" theo R9; bỏ "T7–CN từ …". |

## 6. Test

- **Domain** (TS và Dart, cùng bảng ca §4.4): âm ↔ dương, tháng nhuận, `ruleRanges` qua năm, `ruleCoversDay` với `start`/`until`/ngoại lệ, bậc ưu tiên, cùng bậc cao nhất, `splitRule`, `withException`, `scaledRule` làm tròn, `startingPrice`, `validatePriceRule` (93 ngày, quá khứ, > 2 năm, `weekdays` rỗng, `serviceId` lạ, 31 chuỗi).
- **Functions**: đặt vào Tết năm sau không có dữ liệu năm đó vẫn ra giá Tết; `ruleName` trong snapshot; booking cũ giữ giá khi sửa/xoá chuỗi; trigger `startingPrice` với chuỗi `weekly` rẻ hơn; đặt vào ngày bị bỏ khỏi chuỗi rơi về cuối tuần.
- **Rules**: `price_rules` chủ ghi, khách đọc; `yearly` thiếu `from` bị từ chối; `lunar: true` với `weekly` bị từ chối; `weekly` có `from` bị từ chối; `exceptions` 51 khoá bị từ chối; gói có `dayPrices` hoặc `specialPrice` bị từ chối; `holidays`, `special_days` đọc bị từ chối.
- **Flutter**: `AppCalendar` (ngày âm đúng mùng 1/15 tháng 11/2026, chọn khoảng bằng chạm và kéo, 320 dp, chữ 1,3×, tối/sáng); S08.10 (giá từng ngày khớp domain, ngoại lệ viền, chạm ngày thuộc chuỗi mở S08.10-day); S08.10-new (dropdown lặp lại ghi đúng ngày âm/dương của khoảng, "Mọi gói" tạo đúng số chuỗi và làm tròn); S08.10-day (ba lựa chọn ghi đúng ngoại lệ / cắt chuỗi / đổi chuỗi); S08.10-list; S08.08 dòng giá tính sẵn; S08.09 chỉ một ô giá; S04.02 tên chuỗi dưới ngày; mọi màn ở §5.7 vẫn chọn được ngày và hiện ngày âm.

## 7. Chi phí Google và hiệu năng

Đặt lịch: thay 1 đọc `holidays` + truy vấn `special_days` bằng một truy vấn `price_rules` (≤ 30 tài liệu). S04.02 và S08.10: một truy vấn live. Trigger `price_rules` chạy mỗi lần thợ sửa chuỗi (ít). Không tăng so với spec cũ.

Tính toán (R13, không tính sẵn), đo bằng Python 2026-11-06 làm cận trên với 30 chuỗi một gói trong đó 10 chuỗi âm lịch; TS và Dart nhanh hơn 10–30 lần:

| Việc | Python | TS / Dart ước tính |
|---|---|---|
| `priceForDay`, 30 chuỗi | 0,3 ms | 0,01–0,03 ms |
| `monthPrices` × 24 tháng (730 ngày) | 0,2 s | 10–20 ms |
| `solarToLunar` một ngày | < 0,05 ms | vài µs |

Builder nên đổi dương → âm **một lần mỗi ngày** rồi so với mọi chuỗi âm lịch, không đổi lại cho từng chuỗi.

Khoá: không có. `createBooking` đọc gói và `price_rules` ngoài giao dịch (§4.5), nên việc thợ sửa chuỗi không làm giao dịch đặt lịch của khách chạy lại; giao dịch chỉ khoá lịch ngày như hiện nay. Thợ lưu chuỗi không chờ gì: ghi `price_rules` xong là lịch vẽ lại bằng domain Dart tại máy; trigger chỉ cập nhật `priceSummary` sau đó.

## 8. Ngoài phạm vi

Giá theo giờ trong ngày; lọc và sắp xếp S02.06 theo đúng giá của ngày đã chọn (cần đọc chuỗi của 60 ứng viên mỗi lần đổi bộ lọc, R13); thu/hoàn chênh lệch khi đổi lịch; giá theo ngày cho dịch vụ đi kèm, S29, Chụp ngay, báo giá; S28.06 (studio web) dùng cùng mô hình khi làm #169; nghỉ bù do Chính phủ công bố từng năm (thợ sửa khoảng ngày nếu muốn); nhập hàng loạt từ file.

## 9. Để builder quyết

Đã chốt sau builder check 2026-11-06 (quyết định của người viết spec, chủ dự án xem khi duyệt PR):
- Dữ liệu cũ: PR #326 chưa lên `main`. App khi lưu gói ghi `FieldValue.delete()` cho `dayPrices`, `specialPrice`, `priceMode`, `occasionPrices` nên gói cũ vẫn sửa được dưới rules mới; seed emulator làm lại; một script dọn một lần (`tools/cleanup_day_pricing_v1.ts`, chạy tay) xoá `holidays`, `special_days` và `weekendFrom` trên project staging.
- `AppCalendar`: mọi màn ở §5.7 nằm trong #316 (chủ dự án: "luôn hiển thị ngày âm trên tất cả các màn hình"). Được tách nhiều PR: control + S08.10 + S04.02 trước, các màn còn lại sau.
- Sheet sửa chuỗi hằng năm: "Từ/Tới" hiện lần tới (lần đang diễn ra nếu hôm nay nằm trong khoảng). Lỗi "Chỉ chọn từ hôm nay trở đi" và "Chỉ chọn trong 2 năm tới" chỉ áp cho `repeat: none`.

Chờ chủ dự án chốt: §4.6 mục 4, ghi chuỗi qua callable (rules cấm app ghi thẳng `price_rules`, kiểm một chỗ, chia chuỗi trong một giao dịch) hay app ghi thẳng Firestore như §4.5 (nhanh hơn ở Phase 1, nhưng kiểm hai nơi và phải viết lại đường ghi khi lên Phase 2). Spec đề xuất callable.

- Cách kéo chọn khoảng trên `AppCalendar` (long-press rồi kéo, hay chạm hai đầu); cả hai đều phải có.
- Bộ chọn ngày–tháng âm khi sửa `from`/`to` của chuỗi hằng năm theo âm lịch (wheel hay lịch âm không năm).
- Rút gọn tên chuỗi trong ô lịch S04.02 (cắt chữ hay từ đầu).
- Thứ tự chuỗi trong thẻ ở S08.10 (gợi ý: `weekly` trước, rồi theo ngày tới gần nhất).
