# Đăng việc (khách) và Nhận việc đăng (thợ ảnh)

Màn S15–S16 của phần D trong [`../2026-10-05-provider-types-portfolio-jobs-design.md`](../2026-10-05-provider-types-portfolio-jobs-design.md) (gọi là "spec 10-05"; luồng, trạng thái và quy tắc ở mục 4–5). Mẫu mục và quy ước chung ở [`README.md`](README.md). Mock: `docs/design/ui-mock.html`, mục S15 và S16. Số tiền theo giả định 100% qua app, 2 mốc 50/50 (spec 10-05 mục 4.1).

---

## S15.01 · Đăng việc (2 bước)

- **Thông tin**: `/jobs/new` (bước `what` → `when`) · khách · D4 · Chưa có.
- **Mục đích**: mô tả việc đủ để thợ ảnh báo giá, không lộ thông tin riêng.
- **Điểm vào → ra**: S05.01 tab "Việc đăng" (nút chính hoặc "+"), S02.06 khi không có kết quả, "Đăng lại" ở S15.02 (nháp từ việc cũ) → S15.02 chi tiết việc vừa đăng. Thiếu số điện thoại → S04.05 trước (`returnTo`).
- **Bố cục bước 1/2** (`StepProgress` "1 / 2", nút đóng X): "Bạn cần chụp gì?" + chip thể loại chọn đơn (từ `taxonomy` chuyên môn, "Khác" ở cuối); ô Tiêu đề (bắt buộc, đếm "n / 60"); ô Mô tả (≤ 1000); "Ảnh tham khảo · tuỳ chọn · tối đa 5" lưới 4 ô + ô "+"; ghi chú "Đừng ghi số điện thoại hay địa chỉ cụ thể. Thợ ảnh chỉ thấy quận cho tới khi bạn chọn người."; nút "Tiếp tục".
- **Bố cục bước 2/2** (Back): `SegmentedTabs` Ngày cố định / Linh hoạt; ô "Khi nào" (cố định: ngày + giờ bắt đầu–kết thúc; linh hoạt: khoảng ngày ≤ 30 ngày + thời lượng); ô "Khu vực" (quận, thành phố; dòng phụ "Địa chỉ cụ thể chỉ gửi cho người được chọn"); hàng hai ô "Ngân sách từ" / "Đến" (VND, tuỳ chọn; chip "Để thợ ảnh báo giá" xoá cả hai); ô "Bàn giao mong muốn" (sheet: số ảnh chỉnh tối thiểu, hạn giao); chip "Ai được báo giá" Tất cả / Chỉ Nhiếp ảnh gia / Chỉ Studio; ô "Nhận báo giá trong" (1–7 ngày, mặc định 3); nút "Đăng việc".
- **Dữ liệu**: controller `JobDraftController` giữ cả hai bước; nháp lưu cục bộ khi đóng; `createJob` khi bấm "Đăng việc". Ảnh tham khảo tải lên trước khi gọi (huỷ thì xoá).
- **Trạng thái**: đã có 3 việc đang mở → chặn ở điểm vào với `limit_exceeded` "Bạn đang có 3 việc mở. Đóng bớt một việc để đăng tiếp."; server từ chối chữ có số điện thoại/link → lỗi dưới đúng ô ("Bỏ số điện thoại hoặc link khỏi mô tả"); đang gửi → `AppButton.loading`.
- **Kiểm tra**: tiêu đề 10–60 ký tự; ngân sách "đến" ≥ "từ" > 0; ngày chụp sau hạn nhận báo giá; giờ kết thúc sau giờ bắt đầu.
- **Chuỗi**: `s1501_title` "Đăng việc", `s1501_what` "Bạn cần chụp gì?", `s1501_name` "Tiêu đề · bắt buộc", `s1501_desc` "Mô tả", `s1501_refs` "Ảnh tham khảo · tuỳ chọn · tối đa 5", `s1501_privacy` (ghi chú trên), `s1501_fixed` "Ngày cố định", `s1501_flexible` "Linh hoạt", `s1501_when` "Khi nào", `s1501_area` "Khu vực", `s1501_areaSub` "Địa chỉ cụ thể chỉ gửi cho người được chọn", `s1501_budgetFrom` "Ngân sách từ", `s1501_budgetTo` "Đến", `s1501_budgetOpen` "Để thợ ảnh báo giá", `s1501_wants` "Bàn giao mong muốn", `s1501_who` "Ai được báo giá", `s1501_whoAll` "Tất cả", `s1501_whoArtist` "Chỉ Nhiếp ảnh gia", `s1501_whoStudio` "Chỉ Studio", `s1501_deadline` "Nhận báo giá trong", `s1501_post` "Đăng việc", `s1501_posted` "Đã đăng · đang gợi ý cho {n} thợ ảnh phù hợp".
- **Phân tích**: `job_step{n}`, `job_post{specialty, hasBudget, allowed, flexible}`, `job_post_error{code}`.
- **Chấp nhận**: quay lại bước 1 không mất dữ liệu; đóng giữa chừng hỏi "Lưu nháp?" và mở lại khôi phục nháp; không đăng được khi thiếu SĐT.

## S15.02 · Việc của tôi / chi tiết việc

### Danh sách (tab "Việc đăng" của S05.01)
- **Thông tin**: `/bookings?tab=jobs` · khách · D4 · Chưa có.
- **Bố cục**: `SegmentedTabs` Buổi chụp / Vé sự kiện / Việc đăng (S05.01 và S11.04 gộp còn một hàng tab); `JobCard` (khách): tag thể loại, `StatusBadge` (Đang nhận báo giá · Đã chọn thợ · Đã đóng · Hết hạn), tiêu đề, "ngày · quận · ngân sách", hàng avatar người đã báo giá + "{n} báo giá · {m} mới", thời gian còn; nút chính "Đăng việc mới".
- **Thứ tự**: đang mở (hạn gần trước), rồi đã chọn thợ, rồi đã đóng/hết hạn (mới nhất trước).
- **Tương tác**: chạm thẻ đang mở → chi tiết; "Đã chọn thợ" → S05.02 của booking; "Đã đóng"/"Hết hạn" → chi tiết chỉ đọc kèm "Đăng lại".
- **Trạng thái**: trống → `EmptyState` "Chưa tìm được thợ ưng ý? Đăng việc để thợ ảnh báo giá cho bạn" + "Đăng việc".

### Chi tiết việc (của khách)
- **Thông tin**: `/jobs/:id` (khách là chủ) · khách · D4 · Chưa có.
- **Bố cục**: Back · "…"; tag + `StatusBadge`; tiêu đề (Fraunces 21); "Đăng {ngày} · còn {n} ngày nhận báo giá"; ba `StatTile` Báo giá · Lượt xem · Đã mời; `SectionHeader` "Báo giá mới" + "Xem tất cả"; hai dòng báo giá mới nhất (avatar, tên + `ProviderMark`, bàn giao tóm tắt, giá); dòng tóm tắt việc (ngày giờ, quận, ngân sách, bàn giao); nút viền "Mời thợ ảnh báo giá"; nút chính "So sánh {n} báo giá" (vô hiệu khi 0, chữ "Chưa có báo giá").
- **Tương tác**: "Mời thợ ảnh báo giá" → sheet gợi ý từ `recommend` (chọn tối đa 5 − đã mời; mỗi người một `JobInvite`); "…" → Sửa (chỉ khi 0 báo giá), Gia hạn 7 ngày (một lần), Đóng việc (`ConfirmSheet` nút đỏ "Đóng việc", báo người đã báo giá).
- **Chuỗi**: `s1502_tabJobs` "Việc đăng", `s1502_open` "Đang nhận báo giá", `s1502_awarded` "Đã chọn thợ", `s1502_closed` "Đã đóng", `s1502_expired` "Hết hạn", `s1502_quotes` "{n} báo giá", `s1502_new` "{n} mới", `s1502_left` "còn {n} ngày", `s1502_views` "Lượt xem", `s1502_invited` "Đã mời", `s1502_latest` "Báo giá mới", `s1502_invite` "Mời thợ ảnh báo giá", `s1502_compare` "So sánh {n} báo giá", `s1502_repost` "Đăng lại", `s1502_close` "Đóng việc", `s1502_extend` "Gia hạn 7 ngày".
- **Phân tích**: `job_view_own{status, quotes}`, `job_invite{count}`, `job_close`, `job_extend`.
- **Chấp nhận**: số báo giá cập nhật trực tiếp (nghe `jobs/{id}`); không sửa được nội dung khi đã có báo giá.

## S15.03 · Danh sách báo giá

- **Thông tin**: `/jobs/:id/applications` · khách · D4 · Chưa có. Đích của thông báo gộp `quote_new`.
- **Mục đích**: so sánh giá, bàn giao và độ tin cậy trên một màn.
- **Bố cục**: Back · "{n} báo giá"; chip sắp xếp chọn đơn Phù hợp nhất (mặc định) / Giá thấp / Đánh giá / Đã lưu; danh sách `QuoteCard`: avatar, tên + `ProviderMark` + tag "Được mời" khi có, "🍅 {pct}% · {n} buổi · {k} giải" (NAG) hoặc "· {m} thợ đi cùng" (Studio), giá lớn + dòng so với ngân sách bằng chữ ("trong ngân sách" xanh / "vượt {x}" vàng); `DeliverableChips` (ảnh chỉnh, ngày giao, lần sửa, "Rảnh {ngày}" xanh); câu đầu lời nhắn một dòng; hàng `FitPill` "Hợp {n}%" + nút lưu + nút "Xem".
- **Dữ liệu**: `jobQuotesProvider(jobId, sort)`; "Đã lưu" là danh sách cục bộ theo việc.
- **Trạng thái**: 0 báo giá → `EmptyState` "Đang chờ báo giá đầu tiên" + "Mời thợ ảnh báo giá"; báo giá bị rút → thẻ mờ "Đã rút" trong 24 giờ rồi ẩn.
- **Chuỗi**: `s1503_title` "{n} báo giá", `s1503_sortFit` "Phù hợp nhất", `s1503_sortPrice` "Giá thấp", `s1503_sortRating` "Đánh giá", `s1503_saved` "Đã lưu", `s1503_inBudget` "trong ngân sách", `s1503_overBudget` "vượt {amount}", `s1503_invited` "Được mời", `s1503_free` "Rảnh {date}", `s1503_fit` "Hợp {n}%", `s1503_view` "Xem", `s1503_withdrawn` "Đã rút".
- **Phân tích**: `quotes_view{count, sort}`, `quote_save`.
- **Chấp nhận**: mọi so sánh với ngân sách có chữ; mở từ thông báo gộp đánh dấu đã đọc dòng gộp.

## S15.04 · Chi tiết báo giá

- **Thông tin**: `/jobs/:id/applications/:quoteId` · khách · D4 · Chưa có.
- **Mục đích**: đọc báo giá như một hợp đồng ngắn rồi chọn và trả tiền.
- **Bố cục**: Back · "Báo giá {i} / {n}" · "…"; hàng người báo giá (avatar, tên + `ProviderMark`, loại · % cà chua · số buổi, nút viền "Hồ sơ" → S03.01); thẻ giá: số tiền (Fraunces 24) + so với ngân sách, `MilestoneTable` hai dòng ("1 · Sau buổi chụp · thả cho thợ ảnh", "2 · Khi bạn duyệt ảnh · hoặc tự duyệt sau 3 ngày"); bốn ô bàn giao (ảnh chỉnh, ảnh gốc, ngày giao, lần sửa); lời nhắn dạng bong bóng; album đính kèm (→ S24.01); ghi chú khoá "Bạn trả {giá} ngay, app giữ toàn bộ và chỉ chuyển cho thợ ảnh theo từng mốc."; `AppFooterBar` nút chat + "Chọn và thanh toán {giá}".
- **Tương tác**: vuốt ngang sang báo giá kế (theo thứ tự đang sắp ở S15.03); nút chat mở chat hỏi trước gắn `jobId`; "Chọn và thanh toán" → kiểm SĐT (S04.05) → bước xem lại dùng layout S04.03 (`BookingCard` theo `terms`, ô địa chỉ cụ thể bắt buộc, `MilestoneTable`, `PolicyTable`, `ProviderPicker` MoMo / VNPay) → `acceptQuote` → cổng thanh toán → S04.04 → S05.02. "…" → Từ chối báo giá (lý do tuỳ chọn, thợ ảnh nhận `quote_not_selected`), Báo cáo (S20.01).
- **Trạng thái**: báo giá đã bị rút hoặc việc không còn mở → nút chính vô hiệu kèm lý do; thợ ảnh vừa nhận booking khác trùng ngày → `day_taken` "Thợ ảnh này đã kín lịch ngày đó" và báo giá chuyển "Đã rút".
- **Chuỗi**: `s1504_counter` "Báo giá {i} / {n}", `s1504_profile` "Hồ sơ", `s1504_m1` "Sau buổi chụp", `s1504_m1Sub` "thả cho thợ ảnh", `s1504_m2` "Khi bạn duyệt ảnh", `s1504_m2Sub` "hoặc tự duyệt sau {days} ngày", `s1504_edited` "ảnh chỉnh", `s1504_raw` "ảnh gốc", `s1504_days` "ngày giao", `s1504_revisions` "lần sửa", `s1504_album` "Album · {name}", `s1504_escrow` (ghi chú trên), `s1504_choose` "Chọn và thanh toán {amount}", `s1504_decline` "Từ chối báo giá".
- **Phân tích**: `quote_view{fit, inBudget}`, `quote_accept_start`, `quote_accept_paid`, `quote_decline`.
- **Chấp nhận**: hai mốc cộng đúng bằng giá (làm tròn đồng: mốc 2 nhận phần dư); trả xong việc thành "Đã chọn thợ", booking ở `accepted`, các báo giá khác `not_selected`.

---

## S16.02 · Việc đang tuyển

- **Thông tin**: `/work?tab=jobs` · thợ ảnh · D5 · Chưa có.
- **Mục đích**: tìm việc hợp với mình để báo giá.
- **Bố cục**: thanh đầu "Công việc · Việc đang tuyển" (không có chuông; số thông báo nằm trên tab Hồ sơ); `SegmentedTabs` Hôm nay / Việc tuyển · {n} / Báo giá (S06.01 thêm hàng tab này; "Hôm nay" là nội dung S06.01 cũ); chip lọc Hợp với bạn (mặc định) / Gần tôi / thể loại / Ngân sách; danh sách `JobCard` (thợ ảnh): tag thể loại + "Bạn được mời" khi có, `FitPill`, tiêu đề, "ngày · giờ · quận · khoảng cách", ngân sách (hoặc "Để thợ báo giá"), "{n} báo giá · còn {m} ngày". Việc "Chỉ Nhiếp ảnh gia" với thợ ảnh chưa là NAG: thẻ mờ, `ProviderTag` vàng "Chỉ Nhiếp ảnh gia", dòng khoá "Chỉ NAG báo giá được · bạn còn {k} giải đã duyệt nữa" → S25.01.
- **Tab "Báo giá"**: các báo giá của mình chia Đang chờ / Được chọn / Không được chọn / Đã rút, mỗi dòng mở S16.01.
- **Dữ liệu**: `openJobsProvider(filter)` lấy từ `recommend` cho "Hợp với bạn", truy vấn geohash cho "Gần tôi"; chấm số trên tab Công việc cộng thêm số lời mời chưa xem.
- **Trạng thái**: hồ sơ chưa hoàn tất → `EmptyState` "Hoàn tất hồ sơ để thấy việc đang tuyển" + nút S08.01; không có việc → "Chưa có việc hợp với bạn. Thêm thể loại hoặc mở rộng khu vực." + nút S08.02.
- **Chuỗi**: `s1602_tabToday` "Hôm nay", `s1602_tabJobs` "Việc tuyển · {n}", `s1602_tabQuotes` "Báo giá", `s1602_fit` "Hợp với bạn", `s1602_near` "Gần tôi", `s1602_invited` "Bạn được mời", `s1602_openBudget` "Để thợ báo giá", `s1602_meta` "{n} báo giá · còn {m} ngày", `s1602_artistOnly` "Chỉ Nhiếp ảnh gia", `s1602_artistLock` "Chỉ NAG báo giá được · bạn còn {k} giải đã duyệt nữa".
- **Phân tích**: `open_jobs_view{filter, count}`.
- **Chấp nhận**: "Bạn được mời" luôn ở đầu; không hiện việc ngoài khu vực phục vụ; việc sai loại nhà cung cấp (trừ "Chỉ Nhiếp ảnh gia" với Cá nhân) không hiện.

## S16.01 · Chi tiết việc (thợ ảnh)

- **Thông tin**: `/jobs/:id` (thợ ảnh) · thợ ảnh · D5 · Chưa có. Đích của `job_match`, `job_invited`, `quote_not_selected`.
- **Mục đích**: quyết định có báo giá không trong một cuộn.
- **Bố cục**: Back · lưu · "…"; tag + "Bạn được mời" + `FitPill`; tiêu đề; hàng người đăng (avatar, tên, "Đã thuê {n} lần · SĐT đã xác minh", không có số); `irow` ngày giờ + dòng lịch của mình ("Bạn rảnh ngày này" xanh / "Bạn đã có lịch" đỏ / "Bạn có yêu cầu đang chờ"); `irow` quận + khoảng cách + "Địa chỉ cụ thể gửi khi bạn được chọn"; `irow` ngân sách + bàn giao mong muốn; mô tả; ảnh tham khảo (3 cột, chạm phóng to); "{n} thợ ảnh đã báo giá · còn {m} ngày"; `AppFooterBar` nút chat ("Hỏi khách") + "Gửi báo giá".
- **Khi đã báo giá**: thẻ "Báo giá của bạn · {giá} · {trạng thái}" trên nút; nút chính thành "Sửa báo giá"; chữ đỏ "Rút báo giá" (`ConfirmSheet`). Được chọn → thẻ "Khách đã chọn bạn" + "Mở buổi chụp" (S05.02).
- **Trạng thái**: ngày đã kín → nút chính vô hiệu "Ngày này bạn đã có lịch"; việc "Chỉ Nhiếp ảnh gia" mà mình là Cá nhân → nút vô hiệu + lối S25.01; việc đã đóng → chỉ đọc, "Việc đã đóng".
- **Chuỗi**: `s1601_hirer` "Đã thuê {n} lần", `s1601_phoneOk` "SĐT đã xác minh", `s1601_free` "Bạn rảnh ngày này", `s1601_busy` "Bạn đã có lịch", `s1601_pending` "Bạn có yêu cầu đang chờ", `s1601_areaSub` "Địa chỉ cụ thể gửi khi bạn được chọn", `s1601_competition` "{n} thợ ảnh đã báo giá · còn {m} ngày", `s1601_ask` "Hỏi khách", `s1601_quote` "Gửi báo giá", `s1601_edit` "Sửa báo giá", `s1601_withdraw` "Rút báo giá", `s1601_mine` "Báo giá của bạn · {amount} · {status}", `s1601_chosen` "Khách đã chọn bạn", `s1601_closed` "Việc đã đóng".
- **Phân tích**: `job_view{fit, invited}`, `job_ask`, `quote_withdraw`.
- **Chấp nhận**: không có số điện thoại hay địa chỉ cụ thể của khách trên màn; mở màn tăng `viewCount` một lần mỗi thợ ảnh.

## S16.03 · Gửi báo giá (sheet)

- **Thông tin**: sheet cao tối đa 95% trên S16.01 · thợ ảnh · D5 · Chưa có.
- **Bố cục**: tiêu đề "Gửi báo giá" + "Ngân sách khách {khoảng}"; ô "Dựa trên gói · tuỳ chọn" (mở danh sách gói `active`; chọn thì điền giá, ảnh chỉnh, hạn giao, lần sửa); ô "Giá báo · bắt buộc" (VND, bàn phím số); dòng mốc tự tính "Mốc 1 sau buổi chụp {a} · Mốc 2 khi khách duyệt ảnh {b}"; hàng ba ô Ảnh chỉnh / Giao trong / Sửa; ô "Lời nhắn · bắt buộc" (20–500, đếm); ô "Album đính kèm · tuỳ chọn" (một album không trống của mình); ghi chú "Khách chọn và trả tiền thì buổi chụp được xác nhận luôn. Sửa hoặc rút báo giá được tới lúc đó."; nút chính "Gửi báo giá" (sửa: "Lưu báo giá").
- **Kiểm tra**: giá > 0; lần sửa 0–5; ngày giao 1–60; lời nhắn có số điện thoại/link → lỗi dưới ô "Bỏ số điện thoại hoặc link khỏi lời nhắn"; vượt 20 báo giá đang mở → `limit_exceeded`; sai loại nhà cung cấp → `not_eligible`; ngày kín → `day_taken`.
- **Dữ liệu**: `submitQuote({jobId, terms, message, albumId?, basedOnServiceId?})`; sửa dùng cùng callable (ghi đè báo giá của mình).
- **Chuỗi**: `s1603_title` "Gửi báo giá", `s1603_budget` "Ngân sách khách {range}", `s1603_basedOn` "Dựa trên gói · tuỳ chọn", `s1603_price` "Giá báo · bắt buộc", `s1603_milestones` "Mốc 1 sau buổi chụp {a} · Mốc 2 khi khách duyệt ảnh {b}", `s1603_edited` "Ảnh chỉnh", `s1603_delivery` "Giao trong", `s1603_revisions` "Sửa", `s1603_message` "Lời nhắn · bắt buộc", `s1603_album` "Album đính kèm · tuỳ chọn", `s1603_note` (ghi chú trên), `s1603_send` "Gửi báo giá", `s1603_save` "Lưu báo giá".
- **Phân tích**: `quote_submit{basedOnService, hasAlbum, inBudget}`, `quote_error{code}`.
- **Chấp nhận**: mốc hiện ngay khi gõ giá và cộng đúng bằng giá; đóng khi đã nhập hỏi "Bỏ báo giá?"; gửi xong khách nhận `quote_new` (gộp theo việc).
