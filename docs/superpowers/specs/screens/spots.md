# Điểm chụp đang hot (S29)

Màn của [`../2026-10-08-trending-spots-design.md`](../2026-10-08-trending-spots-design.md) (gọi là "spec 10-08"). Mẫu mục và quy ước chung ở [`README.md`](README.md). Mock: `docs/design/ui-mock.html`, mục S29 và các biến thể `S02.01-spots`, `S02.03-spots`, `S04.02-spot`, `S10.01-spot`, `S12.01-spot`. Luật tiền, hoàn huỷ, liên hệ sau thanh toán và "chỉ nhà cung cấp đã duyệt mới nhận đơn" giữ nguyên (T9). Mã S28 để dành cho studio trên web (#161).

Dữ liệu dùng chung: `spotRankingProvider(areaCode)` (một tài liệu `spot_rankings/{areaCode}`, rơi về `spot_rankings/all`), `spotsProvider(filter)` (phân trang 20), `spotProvider(spotId)`, `spotSchedulesProvider(spotId)` (lịch `open`), `spotDaysProvider(scheduleId, day)` (giờ đã có người), `spotSlotOffersProvider(spotId)`, `mySpotSchedulesProvider`. Mọi collection mới chỉ server ghi; app ghi qua callable `saveSpotSchedule`, `cancelSpotSchedule`, `saveSlotOffer`, `closeSlotOffer` (vùng `asia-southeast1`). Repository là interface ở domain; adapter Firestore nằm ở `lib/data/spots/`.

---

## Thay đổi ở màn đã có

### S02.01 · Trang chủ: khu "Điểm chụp đang hot"
- Khu cuộn ngang nằm giữa thẻ ảnh lớn và "Rảnh tuần này". Đọc **một** tài liệu `spot_rankings/{areaCode}` mỗi lần mở (khu vực từ vị trí gần đúng hoặc S02.05).
- `SpotCard` dọc 4:5: ảnh bìa, nhãn "Đang vào mùa" (pill trắng, biểu tượng `eco`) nếu trong mùa, tên, thành phố, "{n} thợ nhận chụp tuần này". "Xem tất cả" → S29.01; chạm thẻ → S29.02.
- **Trạng thái**: không có điểm → khu không hiện; đang tải → skeleton của `SpotCard`.
- **Chuỗi**: `s0201_spotsTitle` "Điểm chụp đang hot", `spotInSeason` "Đang vào mùa", `spotProvidersThisWeek` "{n} thợ nhận chụp tuần này".
- **Chấp nhận**: mở Trang chủ chỉ đọc một tài liệu xếp hạng (test với repository giả đếm lượt đọc).

### S02.03 · Khám phá: tab "Địa điểm"
- Đoạn "Địa điểm" thành lưới `SpotCard` 2 cột: điểm hot trước, rồi theo khoảng cách (vị trí gần đúng, S02.04) hoặc theo khu vực đã chọn. Tiêu đề "Điểm chụp" + "Xem tất cả" → S29.01. Thẻ xin vị trí và "Sự kiện chụp ảnh" vẫn ở dưới lưới.
- S02.04 (đã bật vị trí): hàng cuộn ngang "Điểm chụp gần bạn" phía trên danh sách sự kiện.
- **Chuỗi**: `s0203_spots` "Điểm chụp", `s0204_spotsNearby` "Điểm chụp gần bạn".

### S04 · Đặt lịch có ngữ cảnh điểm (S04.02-spot)
- Vào từ "Đặt" trên thẻ thợ ở S29.02, mang `spotId` và `spotScheduleId`.
- **S04.01**: chỉ các gói trong `serviceIds` của lịch (rỗng = mọi gói đang bật); khối "Thêm dịch vụ" như spec dịch vụ đi kèm.
- **S04.02**: dòng địa điểm "Đồi chè Cầu Đất, Đà Lạt" / "Lịch tại điểm · T7, CN · 06:00–11:00"; lịch tháng chỉ bật ngày thuộc lịch (chọn sẵn ngày đang xem ở S29.02), ngày khác chữ mờ; chip giờ chỉ trong khung của lịch, đã bỏ giờ chồng với `spot_days.taken` và giữ cách ≥ 15 phút; chú giải "Chỉ ngày có lịch tại điểm".
- **S04.06**: địa điểm khoá là điểm chụp (không sửa); vẫn có "Điểm đón" nếu đã chọn xe.
- **S04.03**: thêm dòng "Tại {tên điểm}". Booking lưu `spotId`, `source = spot`.
- **Lỗi**: `outside_schedule`, `slot_taken` ("Giờ này vừa có người đặt. Chọn giờ khác.", quay lại S04.02 và tải lại giờ), `spot_archived`.
- **Chuỗi**: `s0402_spotOnly` "Chỉ ngày có lịch tại điểm", `s0402_spotWindow` "Chỉ giờ còn trống trong khung {start}–{end} của {name}", `s0403_atSpot` "Tại {spot}".

### S06.01 · Công việc: lối vào "Lịch tại điểm"
- Dòng "Lịch tại điểm · {n} đang mở" dưới hàng KPI → S29.03. Không có lịch: "Lịch tại điểm" + mô tả ngắn "Nhận chụp ở điểm đang hot".

### S10.01 · Đăng bài: chip gắn điểm (S10.01-spot)
- Địa điểm bài nằm trong bán kính một điểm `active` → chip "Gắn với {tên điểm} ×" dưới hàng Địa điểm, mặc định đã gắn; chạm để bỏ. Lưu `Post.spotId`.
- Bài ẩn, đang chờ duyệt hoặc bị gỡ do báo cáo (S20) không hiện ở trang điểm và không được tính.
- **Chuỗi**: `s1001_spotChip` "Gắn với {spot}", `s1001_spotChipRemove` (nhãn đọc) "Bỏ gắn với {spot}".
- **Chấp nhận**: đổi địa điểm ra ngoài bán kính thì chip biến mất; bỏ chip rồi đăng → bài không có `spotId`.

### S12.01 · Tạo sự kiện: ô "Điểm chụp" (S12.01-spot)
- Ô bắt buộc "Điểm chụp" dưới tên sự kiện, mở sheet: ô tìm theo tên; gợi ý điểm `active` gần khu vực của người tổ chức, điểm hot trước; lựa chọn cuối "Không thuộc điểm chụp nào" ("Sự kiện không hiện ở trang điểm nào"). Nút chính "Chọn {tên điểm}".
- Chọn điểm thì S12.02 điền sẵn địa điểm là điểm đó, sửa được trong bán kính của điểm. Lưu `Event.spotId?`; sửa sự kiện đổi được điểm.
- **Kiểm tra**: chưa chọn → lỗi dưới ô "Chọn một điểm chụp, hoặc Không thuộc điểm chụp nào".
- **Chuỗi**: `s1201_spot` "Điểm chụp · bắt buộc", `s1201_spotSheet` "Điểm chụp", `s1201_spotHint` "Sự kiện gắn điểm hiện ở trang điểm chụp và được tính vào độ hot.", `s1201_spotNone` "Không thuộc điểm chụp nào", `s1201_spotNoneSub` "Sự kiện không hiện ở trang điểm nào", `s1201_spotRequired`.

---

## S29.01 · Điểm chụp

- **Thông tin**: `/spots` · khách · thợ ảnh · studio · spec 10-08 · Chưa có.
- **Mục đích**: tìm một nơi đang đẹp để chụp.
- **Điểm vào → ra**: "Xem tất cả" ở S02.01 và S02.03 → S29.02.
- **Bố cục**: thanh trên Back · "Điểm chụp"; hàng chip lọc: "Khu vực" (sheet chọn khu vực như S02.05), "Đang vào mùa", "Cuối tuần này có thợ"; dòng đếm "{n} điểm…"; danh sách `SpotCard` lớn (ảnh bìa 16:9, nhãn "Đang vào mùa", tên, "{thành phố} · Mùa đẹp tháng {a}–{b}" hoặc "Đẹp quanh năm", "{n} thợ · {m} sự kiện sắp tới").
- **Dữ liệu**: `spotsProvider(filter)`: thứ tự ghim → `hotScore` → còn lại theo khoảng cách; phân trang 20; chỉ điểm `active`, không ẩn.
- **Trạng thái**: trống → `EmptyState` "Chưa có điểm chụp nào ở khu vực này"; skeleton thẻ lớn khi tải.
- **Tương tác**: chạm thẻ → S29.02; đổi chip tải lại từ đầu.
- **Chuỗi**: `s2901_title` "Điểm chụp", `s2901_area` "Khu vực", `s2901_inSeason` "Đang vào mùa", `s2901_weekend` "Cuối tuần này có thợ", `spotSeason` "Mùa đẹp tháng {from}–{to}", `spotYearRound` "Đẹp quanh năm", `s2901_counts` "{n} thợ · {m} sự kiện sắp tới", `s2901_empty` "Chưa có điểm chụp nào ở khu vực này".
- **Phân tích**: `spot_list_filter{inSeason, weekend, area}`.
- **Chấp nhận**: không hiện điểm số hay chữ "ghim"; điểm ngoài mùa không có nhãn mùa; mùa vắt qua năm (tháng 12–1) hiển thị đúng.

## S29.02 · Trang điểm chụp

- **Thông tin**: `/spots/:spotId` · khách · thợ ảnh · studio · spec 10-08 · Chưa có.
- **Mục đích**: biết ai chụp ở đây vào ngày nào và đặt ngay.
- **Điểm vào → ra**: S02.01, S02.03, S29.01, link chia sẻ → S03.01 ("Hồ sơ"), luồng S04 ("Đặt"), S29.06 ("Chọn suất"), S11.02, S02.02.
- **Bố cục** (theo mock S29.02 và S29.02-more): ảnh bìa + Back + chia sẻ; tên (Fraunces), thành phố; nhãn "Đang vào mùa · tới cuối tháng {m}" hoặc dòng "Mùa đẹp: tháng {a}–{b}"; mô tả; khối "Mẹo chụp" (tối đa 5); bản đồ nhỏ tĩnh + nút viền "Chỉ đường" (mở app bản đồ của máy); "Thợ nhận chụp ở đây": chip ngày (Hôm nay · các ngày có lịch trong 14 ngày tới · Chọn ngày) và `PhotographerCard` gọn (tên + `ProviderMark`/`ProviderTag`, "Có mặt {thứ} {ngày} · {giờ}–{giờ}", % cà chua, giá từ, "Hồ sơ" viền + "Đặt" nhỏ); "Gói chụp tại điểm": `SlotOfferCard` (tên, thợ, số ảnh chỉnh, số ngày giao, "Còn {n} suất {ngày}", giá, nút nhỏ "Chọn suất"); "Sự kiện ở đây": `EventCard`; "Ảnh chụp ở đây": masonry bài gắn điểm + số bài. Cuộn qua ảnh bìa thì thanh trên thu gọn còn tên điểm + chia sẻ. Không có nút gradient lớn.
- **Dữ liệu**: `spotProvider`, `spotSchedulesProvider` (≤ 20), `spotDaysProvider` của ngày đang xem, `spotSlotOffersProvider`, sự kiện `open`/`full` sắp tới (≤ 10), bài gắn điểm 20 mỗi trang (mới nhất trước). Khoảng 50–60 lượt đọc mỗi lần mở.
- **Trạng thái**: mặc định chọn ngày gần nhất có thợ; ngày không có thợ → khối "Chưa có thợ nhận chụp ngày này" + link "Xem ngày khác" (sang ngày gần nhất có thợ) (S29.02-empty); ngoài mùa → dòng mùa thay nhãn (S29.02-offseason); không có gì sắp tới → chỉ mô tả, mẹo, bản đồ, ảnh + dòng "Bạn là thợ ảnh? Thêm lịch chụp ở điểm này trong Công việc." (chỉ nhà cung cấp thấy, chạm → S29.04 chọn sẵn điểm); điểm `archived` → dải "Điểm này không còn nhận lịch mới"; khối không có dữ liệu thì ẩn.
- **Tương tác**: "Đặt" → luồng S04 có ngữ cảnh điểm (mục S04 ở trên); "Chọn suất" → S29.06; "Hồ sơ" → S03.01; ảnh → S02.02; sự kiện → S11.02; chia sẻ → link `/spots/:spotId`.
- **Chuỗi**: `s2902_inSeasonUntil` "Đang vào mùa · tới cuối tháng {m}", `s2902_season` "Mùa đẹp: tháng {from}–{to}", `s2902_tips` "Mẹo chụp", `s2902_directions` "Chỉ đường", `s2902_providers` "Thợ nhận chụp ở đây", `s2902_today` "Hôm nay", `s2902_pickDate` "Chọn ngày", `s2902_present` "Có mặt {day} · {start}–{end}", `s2902_book` "Đặt", `s2902_profile` "Hồ sơ", `s2902_slots` "Gói chụp tại điểm", `s2902_slotsLeft` "Còn {n} suất {day}", `s2902_pickSlot` "Chọn suất", `s2902_events` "Sự kiện ở đây", `s2902_photos` "Ảnh chụp ở đây", `s2902_noProviders` "Chưa có thợ nhận chụp ngày này", `s2902_otherDay` "Xem ngày khác", `s2902_providerHint` "Bạn là thợ ảnh? Thêm lịch chụp ở điểm này trong Công việc.", `s2902_archived` "Điểm này không còn nhận lịch mới".
- **Phân tích**: `spot_view{spotId, inSeason}`, `spot_book_tap{spotId, providerId}`, `spot_slot_tap{spotId, offerId}`.
- **Chấp nhận**: chỉ nhà cung cấp `acceptsOrders` có thẻ; không hiện số điện thoại; đổi chip ngày chỉ đọc lại `spot_days` của ngày đó; 320 dp và chữ 1,3× không cắt tên thợ.

## S29.03 · Lịch tại điểm của tôi

- **Thông tin**: `/me/spot-schedules` · thợ ảnh · studio · spec 10-08 · Chưa có.
- **Mục đích**: xem và quản lý các lịch nhận chụp tại điểm.
- **Điểm vào → ra**: S06.01 dòng "Lịch tại điểm", S29.02 (dòng gợi ý cho nhà cung cấp) → S29.04, S29.05.
- **Bố cục**: Back · "Lịch tại điểm"; dòng "{n} / 8 lịch đang mở"; mỗi lịch một thẻ: ảnh điểm, tên điểm, ngày ("T7, CN · 10/10–15/11"), "{n} ngày · {giờ}–{giờ} · {k} gói", chip booking theo ngày ("T7 10/10 · 2 booking", "+8 ngày"), gói chia suất (tên, giá, "{n} suất/ngày"), hàng chữ "Sửa" · "Gói chia suất" · "Huỷ lịch" (đỏ); ghi chú T5; nút chính "Thêm lịch tại điểm".
- **Dữ liệu**: `mySpotSchedulesProvider` (lịch `open` của mình hoặc của studio), số booking theo ngày từ `spot_days`.
- **Trạng thái**: trống → `EmptyState` "Chưa có lịch tại điểm" / "Chọn một điểm chụp đang hot và mở lịch cuối tuần để khách đặt." + nút chính; đủ 8 lịch → nút chính tắt (lỗi server `schedule_limit`); chưa nhận đơn (`not_accepting_orders`) → nút chính "Xác minh để mở lịch" → S21.02.
- **Tương tác**: "Huỷ lịch" → `ConfirmSheet` nút đỏ "Huỷ lịch tại {điểm}?"; còn booking → chặn với "Còn {n} booking ngày {ngày}. Liên hệ khách hoặc huỷ từng booking (khách được hoàn 100%)."; "Sửa" → S29.04; "Gói chia suất" → S29.05.
- **Chuỗi**: `s2903_title` "Lịch tại điểm", `s2903_count` "{n} / 8 lịch đang mở", `s2903_bookingsOnDay` "{day} · {n} booking", `s2903_slotPerDay` "{n} suất/ngày", `s2903_edit` "Sửa", `s2903_slotOffer` "Gói chia suất", `s2903_cancel` "Huỷ lịch", `s2903_cancelTitle` "Huỷ lịch tại {spot}?", `s2903_cancelBlocked` "Còn {n} booking ngày {day}. Liên hệ khách hoặc huỷ từng booking (khách được hoàn 100%).", `s2903_add` "Thêm lịch tại điểm", `s2903_emptyTitle` "Chưa có lịch tại điểm", `s2903_emptyBody` "Chọn một điểm chụp đang hot và mở lịch cuối tuần để khách đặt.", `s2903_rule` "Ngày tại điểm chỉ nhận booking ở điểm đó, nhiều booking không chồng giờ. Ngày đó bạn không nhận booking ở nơi khác.".
- **Phân tích**: `spot_schedule_cancel{blocked}`.
- **Chấp nhận**: huỷ lịch còn booking không gọi được `cancelSpotSchedule`; studio thấy lịch của studio, thợ thành viên không sửa được lịch studio.

## S29.04 · Thêm / sửa lịch tại điểm

- **Thông tin**: `/me/spot-schedules/new`, `/me/spot-schedules/:id/edit` · thợ ảnh · studio · spec 10-08 · Chưa có.
- **Mục đích**: mở các ngày nhận chụp ở một điểm.
- **Bố cục**: Back · "Thêm lịch tại điểm" (sửa: "Sửa lịch tại điểm") · "{n} / 8"; ô "Điểm chụp" (mở sheet tìm theo tên; gợi ý điểm trong khu vực phục vụ, điểm hot trước); "Ngày": `SegmentedTabs` "Lặp lại" (ô chọn thứ T2–CN + "Từ ngày" / "Tới ngày") / "Chọn ngày" (lịch tháng, chọn nhiều); "Bắt đầu" / "Kết thúc"; "Gói đặt được" (chip chọn nhiều; gói dài hơn khung giờ mờ); thẻ xem trước "{n} ngày · {giờ}–{giờ}" + danh sách ngày, ngày trùng đỏ kèm lý do; nút chính "Mở lịch" (sửa: "Lưu thay đổi").
- **Kiểm tra** (client và server): ngày trong 60 ngày tới, tối đa 40 ngày; khung 05:00–21:00, dài 1–12 giờ; tối đa 8 lịch `open`; ngày đã `booked` / `pending` / `off` → đỏ ("{ngày} đã có booking ở nơi khác", "{ngày} đang có booking chờ nhận", "{ngày} bạn đã đánh dấu nghỉ"), chạm ngày đỏ để bỏ; còn ngày đỏ thì "Mở lịch" tắt; server trả `day_conflict` kèm danh sách ngày.
- **Trạng thái**: ngày đã chọn rơi ngoài mùa của điểm → dòng nhắc "Điểm này đẹp nhất tháng {mùa}"; sửa và bỏ một ngày còn booking → chặn như S29.03.
- **Dữ liệu**: `saveSpotSchedule({spotId, days, window, serviceIds})`; xem trước tính trên máy từ lịch của mình (`availability`).
- **Chuỗi**: `s2904_title` "Thêm lịch tại điểm", `s2904_editTitle` "Sửa lịch tại điểm", `s2904_spot` "Điểm chụp", `s2904_days` "Ngày", `s2904_repeat` "Lặp lại", `s2904_pick` "Chọn ngày", `s2904_from` "Từ ngày", `s2904_to` "Tới ngày", `s2904_start` "Bắt đầu", `s2904_end` "Kết thúc", `s2904_services` "Gói đặt được", `s2904_preview` "{n} ngày · {start}–{end}", `s2904_conflictBooked` "{day} đã có booking ở nơi khác. Bỏ ngày này để mở lịch.", `s2904_offSeason` "Điểm này đẹp nhất tháng {season}", `s2904_open` "Mở lịch", `s2904_save` "Lưu thay đổi".
- **Phân tích**: `spot_schedule_save{days, windowHours, conflicts}`.
- **Chấp nhận**: không gửi được khi còn ngày đỏ; mở xong về S29.03 với toast "Đã mở lịch" và gợi ý thêm gói chia suất.

## S29.05 · Gói chia suất (sheet)

- **Thông tin**: sheet trên S29.03 · thợ ảnh · studio · spec 10-08 · Chưa có.
- **Mục đích**: bán suất ngắn giá cố định trong khung giờ của lịch.
- **Bố cục**: tiêu đề "Gói chia suất" + đóng; dòng lịch "{điểm} · {thứ} · {giờ}–{giờ}"; "Tên gói" (đếm "n/60"); "Giá mỗi suất" + "Giao ảnh trong"; "Số ảnh" + "Số ảnh chỉnh"; bộ đếm "Thời lượng suất" (15–90 phút) và "Nghỉ giữa suất" (0–30 phút); xem trước "{n} suất/ngày: 06:00, 06:40 …"; ghi chú "Gói chia suất không kèm dịch vụ đi kèm. Tối đa 2 gói mỗi lịch."; nút chính "Lưu". Khi sửa có thêm chữ đỏ "Đóng gói" (`ConfirmSheet` nút đỏ; booking đã đặt giữ nguyên).
- **Kiểm tra**: tên 3–60 ký tự, giá > 0 (VND nguyên), tối đa 2 gói mỗi lịch; khung giờ không chia hết thì phần dư bỏ trống (`slotsFor(window, slotMinutes, gapMinutes)` của domain).
- **Dữ liệu**: `saveSlotOffer`, `closeSlotOffer`.
- **Chuỗi**: `s2905_title` "Gói chia suất", `s2905_name` "Tên gói", `s2905_price` "Giá mỗi suất", `s2905_delivery` "Giao ảnh trong", `s2905_photos` "Số ảnh", `s2905_edited` "Số ảnh chỉnh", `s2905_slot` "Thời lượng suất", `s2905_gap` "Nghỉ giữa suất", `s2905_preview` "{n} suất/ngày: {times}", `s2905_note` "Gói chia suất không kèm dịch vụ đi kèm. Tối đa 2 gói mỗi lịch.", `s2905_save` "Lưu", `s2905_close` "Đóng gói".
- **Chấp nhận**: xem trước khớp `slotsFor` cho mọi tổ hợp (khung không chia hết, nghỉ 0).

## S29.06 · Chọn suất (sheet, phía khách)

- **Thông tin**: sheet trên S29.02 · khách · spec 10-08 · Chưa có.
- **Mục đích**: chọn một suất và đi thẳng tới thanh toán.
- **Bố cục**: dòng "{gói} · {thợ}"; tiêu đề "Chọn suất"; chip ngày (ngày của lịch còn suất); dòng "{Thứ}, {ngày} · còn {n} / {tổng} suất"; lưới suất 4 cột (giờ bắt đầu + giờ kết thúc; suất kín mờ với chữ "Đã kín", không chọn được); dòng "Tại {điểm} · {k} ảnh chỉnh · giao trong {d} ngày. Gói chia suất không kèm dịch vụ đi kèm."; nút chính "Tiếp tục · {giá}".
- **Dữ liệu**: `spotSlotOffersProvider`, `spotDaysProvider(scheduleId, day)`; chip ngày chỉ gồm các ngày của lịch từ hôm nay đến hôm nay + 14 (như S29.02), nên mở sheet đọc tối đa 15 tài liệu `spot_days`.
- **Tương tác**: "Tiếp tục" → S04.03 (bỏ S04.01, S04.02, S04.06; dòng "Tại {điểm}"); booking lưu `spotId`, `source = spot_slot`, `slotOfferId`, qua `buildBookingDraft` + `assertOrderAllowed`. Hai khách cùng suất: người sau nhận `slot_taken` → SnackBar "Suất này vừa có người đặt. Chọn suất khác." và lưới tải lại.
- **Chuỗi**: `s2906_title` "Chọn suất", `s2906_left` "{day} · còn {n} / {total} suất", `s2906_full` "Đã kín", `s2906_note` (dòng trên), `s2906_continue` "Tiếp tục · {price}", `s2906_taken` "Suất này vừa có người đặt. Chọn suất khác.".
- **Phân tích**: `spot_slot_pick{offerId, day}`.
- **Chấp nhận**: suất kín không chọn được và có chữ (không chỉ dựa vào độ mờ); trình đọc màn hình đọc "08:40 đến 09:10, còn trống".
