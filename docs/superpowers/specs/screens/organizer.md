# Chủ sự kiện & vé vào cửa (S30)

Màn của [`../2026-10-12-spot-organizer-entry-tickets-design.md`](../2026-10-12-spot-organizer-entry-tickets-design.md) (gọi là "spec 10-12"). Mẫu mục và quy ước chung ở [`README.md`](README.md). Mock: `docs/design/ui-mock.html`, mục S30. Các biến thể của màn đã có cũng nằm trong mục đó: `S29.02-entry`, `S04.03-entry`, `S05.02-pass`, `S05.02-askshot`, `S06.01-scan`, `S11.02-venue-consent`, `S11.04-entry`, `S12.01-venue`, `S12.03-entry`. Luật tiền, hoàn huỷ, liên hệ sau thanh toán và "chỉ nhà cung cấp đã duyệt mới nhận đơn" giữ nguyên (E11).

**Dữ liệu dùng chung:**
- Provider: `organizerProvider(uid)`, `myOrganizerProvider`, `managedSpotsProvider`, `spotResidentsProvider(spotId)`, `entryEventProvider(spotId)` (sự kiện `type = entry` đang bán), `entryDayProvider(eventId, day)` (`entry_days`), `gateStaffProvider`, `myPassProvider(bookingId | regId)` (đọc `private/pass`, có cache để dùng khi không có mạng).
- Mọi collection mới chỉ server ghi. App ghi qua các callable ở §9.2 của spec 10-12, vùng `asia-southeast1`.
- Repository là interface ở domain; adapter Firestore nằm ở `lib/data/organizer/`.
- Camera dùng `mobile_scanner`, chỉ được gọi từ adapter `lib/core/scan/` qua port `PassScanner`.

---

## S30.01 · Trở thành chủ sự kiện

- **Thông tin**: `/organizer/apply` · mọi người dùng · ✅ [#223](https://github.com/thanhngochoang/booking/issues/223) (PR #314).
- **Mục đích**: có tư cách chủ sự kiện để tạo sự kiện và quản lý địa điểm.
- **Điểm vào → điểm ra**:
  - Vào: S09.02, dòng "Tổ chức sự kiện / quản lý địa điểm". Nếu đã là chủ sự kiện, dòng này đổi thành "Địa điểm của tôi" → S30.03, hoặc → S30.02 khi chưa quản lý điểm nào.
  - Ra: gửi xong → S30.02.
- **Bố cục** (từ trên xuống):
  1. Hình minh hoạ, tiêu đề, mô tả.
  2. Ảnh đại diện và ô "Tên tổ chức" (bộ đếm 60).
  3. Ô "Giới thiệu" (≤ 300).
  4. Dòng "Số điện thoại đã xác minh".
  5. Dòng "Bán vé có thu phí: cần xác minh doanh nghiệp".
  6. Nút chính "Gửi yêu cầu".
- **Trạng thái**: chưa xác minh số điện thoại thì nút chính thành "Xác minh số điện thoại" → S21.01. Tư cách bị gỡ (`suspended`) thì hiện dải "Tài khoản tổ chức đang bị tạm khoá · Liên hệ hỗ trợ".
- **Tương tác**: callable `becomeOrganizer`. Tên 3–60 ký tự; lỗi hiện dưới ô.
- **Chuỗi**: `s3001_title` "Tổ chức sự kiện", `s3001_headline` "Bán vé và quản lý địa điểm", `s3001_name` "Tên tổ chức", `s3001_bio` "Giới thiệu", `s3001_businessNote` "Bán vé có thu phí: cần xác minh doanh nghiệp", `s3001_submit` "Gửi yêu cầu".
- **Chấp nhận**:
  - Gửi xong, `organizers/{uid}.status = active`, và dòng ở S09.02 đổi.
  - Người chưa xác minh doanh nghiệp tạo được sự kiện miễn phí, nhưng không đặt được giá.

## S30.02 · Nhận quản lý điểm chụp

- **Thông tin**: `/organizer/spots/claim` · chủ sự kiện · ✅ [#223](https://github.com/thanhngochoang/booking/issues/223) (PR #314).
- **Mục đích**: xin quyền quản lý một điểm S29.
- **Điểm vào → điểm ra**: vào sau S30.01, hoặc từ S30.03 ("Thêm điểm"); gửi xong → S30.03 hiện dải "Đang chờ staff duyệt".
- **Bố cục** (từ trên xuống):
  1. Ô tìm kiếm.
  2. Danh sách điểm: điểm đã có chủ thì mờ, kèm chữ "đã có chủ quản lý".
  3. Khối "Minh chứng là ban quản lý": 1–3 tệp, PDF hoặc ảnh, mỗi tệp ≤ 10 MB.
  4. Ghi chú về thời gian duyệt.
  5. Nút chính "Gửi yêu cầu".
- **Trạng thái**:
  - Không tìm thấy điểm: hiện "Không thấy địa điểm của bạn? Gửi đề xuất điểm mới" (gửi tên và địa chỉ cho staff).
  - Yêu cầu đang chờ: màn chỉ đọc.
  - Bị từ chối: hiện lý do và "Gửi lại".
- **Tương tác**: callable `claimSpot`. Tệp tải lên Storage `spot_claims/{id}/…`, chỉ người gửi và staff đọc được. Lỗi `spot_managed`.
- **Chuỗi**: `s3002_title` "Nhận quản lý điểm", `s3002_proof` "Minh chứng là ban quản lý", `s3002_addFile` "+ Thêm tệp (hợp đồng thuê, quyết định giao quản lý)", `s3002_managed` "đã có chủ quản lý", `s3002_review` "Staff duyệt trong 2 ngày làm việc…".
- **Chấp nhận**: không gửi được khi chưa có tệp nào; staff duyệt thì nhận thông báo `spot_claim_approved`, chạm vào mở S30.03.

## S30.03 · Quản lý điểm

- **Thông tin**: `/organizer/spots/:spotId` · chủ quản lý của điểm · ✅ [#223](https://github.com/thanhngochoang/booking/issues/223) (PR #314).
- **Mục đích**: theo dõi vé, người vào, thợ tại điểm, và sự kiện của người khác ở điểm đang chờ đồng ý.
- **Bố cục**: thanh trên có nút "Xem trang điểm" (mở S29.02); `SegmentedTabs` gồm ba tab:
  - **Vào cửa**:
    - Thẻ vé đang bán: tên, trạng thái, khoảng ngày, giờ, sức chứa, loại vé, KPI hôm nay (đã bán, đã vào, đang giữ).
    - Hai nút viền "Nhân viên soát vé" và "Quét mã".
    - Mục "Sự kiện ở đây chờ bạn đồng ý".
  - **Thợ tại điểm**: danh sách thợ, dòng "Thêm thợ"; sheet thêm/sửa (S30.03-residents) có hai công tắc, số khách tối đa và ngày hết hạn.
  - **Thông tin**: mô tả, mẹo, ảnh bìa, giờ mở cửa, giá tham khảo (`spots.access`: tối đa 6 dòng nhãn và giá, ghi chú).
  - Nút chính: "Tạo vé vào cửa" (hoặc "Sửa vé vào cửa").
- **Trạng thái**:
  - Chưa xác minh doanh nghiệp: nút chính "Xác minh doanh nghiệp để bán vé" → S21.04.
  - Chưa có vé đang bán: thẻ trống "Chưa bán vé qua app · Khách đang thấy giá tham khảo".
  - Danh sách thợ trống: "Thêm thợ chụp thường xuyên ở đây để khách biết họ được miễn vé".
- **Tương tác**:
  - Callable: `updateManagedSpot`, `saveResident`, `removeResident`.
  - Gỡ thợ: sheet xác nhận có nút đỏ.
  - Thêm thợ: tìm theo tên, @username hoặc link hồ sơ; chỉ hiện nhà cung cấp đang nhận đơn; tối đa 50 thợ.
- **Chuỗi**: `s3003_tabEntry` "Vào cửa", `s3003_tabResidents` "Thợ tại điểm · {n}", `s3003_tabInfo` "Thông tin", `s3003_waiveProvider` "Miễn vé cho thợ", `s3003_waiveGuests` "Miễn vé cho khách của thợ", `s3003_maxGuests` "Tối đa {n} khách mỗi buổi", `s3003_validUntil` "Hiệu lực tới", `s3003_offApp` "Thoả thuận giữa bạn và thợ (phí, hợp đồng) nằm ngoài app…", `s3003_pendingEvents` "Sự kiện ở đây chờ bạn đồng ý", `s3003_create` "Tạo vé vào cửa".
- **Chấp nhận**:
  - Thợ vừa thêm hiện ngay nhãn "Thợ tại điểm · miễn vé" ở S29.02 và được bỏ dòng vé ở S04.03-entry.
  - Quyền lợi đã hết hạn thì không còn tác dụng.

## S30.04 · Tạo / sửa vé vào cửa

- **Thông tin**: `/organizer/entry/new`, `/organizer/entry/:eventId/edit` · chủ quản lý của điểm, đã xác minh doanh nghiệp · ✅ [#223](https://github.com/thanhngochoang/booking/issues/223) (PR #314).
- **Mục đích**: mở bán vé vào cửa cho một khoảng ngày.
- **Bố cục** (từ trên xuống):
  1. Tên.
  2. Từ ngày / tới ngày.
  3. Mở / đóng / tối đa mỗi ngày.
  4. Nghỉ trong tuần (7 ô).
  5. Ngày nghỉ lẻ (lịch tháng).
  6. Danh sách loại vé (1–6), mỗi dòng mở sheet sửa tên và giá.
  7. Ghi chú về hoàn tiền và thời điểm chi tiền.
  8. Nút chính "Mở bán" (khi sửa là "Lưu thay đổi").
- **Kiểm tra**:
  - Khoảng ngày ≤ 180 ngày, ngày bắt đầu không ở quá khứ.
  - Giờ đóng cửa sau giờ mở cửa.
  - Tên loại vé 3–40 ký tự, giá là số nguyên VND > 0.
  - Khi sửa: không xoá được loại vé đã bán (chỉ "Ẩn loại vé"); không giảm sức chứa một ngày xuống dưới số vé đã bán của ngày đó.
- **Tương tác**: `createEvent` / `updateEvent` với `type = entry`. Lỗi `business_required`, `not_spot_manager`.
- **Chuỗi**: `s3004_title` "Vé vào cửa", `s3004_open` "Mở", `s3004_close` "Đóng", `s3004_capacity` "Tối đa/ngày", `s3004_closedWeekdays` "Nghỉ trong tuần", `s3004_types` "Loại vé · {n} / 6", `s3004_addType` "+ Thêm loại", `s3004_note` "Khung giờ chỉ là tên loại vé…", `s3004_submit` "Mở bán".
- **Chấp nhận**: mở bán xong, S29.02 hiện khối "Vào cửa" có nút "Mua vé"; sửa giá không làm đổi giá của các đơn đã trả.

## S30.05 · Mua vé vào cửa

- **Thông tin**: `/spots/:spotId/tickets` · khách · ✅ [#223](https://github.com/thanhngochoang/booking/issues/223) (PR #314).
- **Mục đích**: mua vé cho một ngày tham quan.
- **Điểm vào → điểm ra**: vào từ "Mua vé" ở S29.02-entry; thanh toán ở S04.04; xong → S11.04-entry.
- **Bố cục** (từ trên xuống):
  1. Thẻ điểm (ảnh, tên, giờ mở cửa, người bán).
  2. Chip ngày: 14 ngày tới và "Chọn ngày"; ngày hết vé thì mờ.
  3. Bộ đếm cho từng loại vé.
  4. Dòng tổng.
  5. Ghi chú hoàn tiền, có ghi mốc cụ thể.
  6. Nút chính "Thanh toán {tổng}".
- **Trạng thái**: chưa có số điện thoại thì đi S04.05; tổng bằng 0 thì nút tắt; giữ chỗ 15 phút.
- **Tương tác**: callable `registerEntry`, sau đó `createPayment`. Lỗi `sold_out_day` ("Ngày này vừa hết vé. Chọn ngày khác.", tải lại chip ngày), `day_closed`, `limit_exceeded` (tổng > 10).
- **Chuỗi**: `s3005_title` "Vé vào cửa", `s3005_soldOut` "Hết vé", `s3005_total` "{n} vé · {day}", `s3005_oneQr` "Một mã QR cho cả nhóm, đưa ở cổng.", `s3005_refund` "Huỷ trước 48 giờ (trước {cutoff}) hoàn 100%, sau đó không hoàn.", `s3005_pay` "Thanh toán {amount}".
- **Chấp nhận**: hai khách cùng mua những chỗ cuối thì chỉ một người thành công (test Functions); vé hiện ở S11.04 với mã QR dùng được khi không có mạng.

## S30.06 · Nhân viên soát vé

- **Thông tin**: `/organizer/gate-staff` · chủ sự kiện · ✅ [#223](https://github.com/thanhngochoang/booking/issues/223) (PR #314).
- **Mục đích**: cho người ở cổng quyền quét mã, và chỉ quyền đó.
- **Bố cục**:
  - Danh sách nhân viên: avatar, tên, số mã đã quét hôm nay, nhãn "Đang làm" hoặc "Đã mời".
  - Ghi chú quyền hạn (biểu tượng khoá).
  - Nút chính "Mời nhân viên": sheet nhập số điện thoại hoặc @username.
- **Tương tác**: callable `inviteGateStaff` / `removeGateStaff`; người được mời gọi `respondGateStaff` (từ thông báo, trong 72 giờ). Tối đa 10 người. Gỡ: sheet xác nhận có nút đỏ.
- **Phía nhân viên**: Hồ sơ có dòng "Soát vé · {địa điểm}" → S30.07. Nhân viên không mở được S30.03 hay S12.03.
- **Chuỗi**: `s3006_title` "Nhân viên soát vé", `s3006_invite` "Mời nhân viên", `s3006_scope` "Nhân viên chỉ mở được màn quét mã…", `s3006_active` "Đang làm", `s3006_invited` "Đã mời".
- **Chấp nhận**: nhân viên không đọc được thông tin liên hệ của khách (test rules); nhân viên bị gỡ thì quét bị từ chối ngay.

## S30.07 · Quét mã

- **Thông tin**: `/scan` · chủ sự kiện, nhân viên soát vé, thợ, studio · ✅ [#223](https://github.com/thanhngochoang/booking/issues/223) (PR #314).
- **Mục đích**: soát vé ở cổng, check-in người tham gia sự kiện, hoặc thợ xác nhận đã gặp khách (booking chuyển `shooting`).
- **Bố cục**:
  - Camera toàn màn hình, nền tối, khung quét.
  - Nút đóng và nút đèn pin.
  - "Nhập mã 8 ký tự" (sheet có ô nhập mã).
  - Số người đã vào hôm nay (chỉ chủ và nhân viên thấy).
  - Kết quả hiện trong sheet: thành công thì biểu tượng xanh, tiêu đề (ví dụ "Đã vào · 3 người", "Đang chụp · {khách}") và chi tiết; lỗi thì khung đỏ cùng thông báo theo mã lỗi.
  - Nút "Quét tiếp" (kiểu sec), hoặc với thợ là "Về buổi chụp".
- **Trạng thái**:
  - Chưa cấp quyền camera: dùng primer chung (như S17.03), sau đó "Mở cài đặt".
  - Không có mạng: "Chưa quét được, kiểm tra kết nối" và giữ mã để thử lại; không check-in khi không có mạng.
- **Tương tác**: callable `scanPass({code})`. Khi thành công, sheet tự đóng sau 3 giây. Thành công rung ngắn, lỗi rung dài (tắt được). Mã lỗi theo §6.2 spec 10-12.
- **Chuỗi**: `s3007_hint` "Đưa mã QR vào khung", `s3007_manual` "Nhập mã 8 ký tự", `s3007_today` "Hôm nay: {in} / {sold} khách đã vào", `s3007_entered` "Đã vào · {n} người", `s3007_shooting` "Đang chụp · {name}", `s3007_wrongDay` "Vé ngày {day}", `s3007_already` "Đã vào lúc {time}", `s3007_tooEarly` "Mở quét từ {time}", `s3007_refunded` "Vé đã hoàn", `s3007_notYours` "Mã này không thuộc sự kiện hoặc buổi chụp của bạn", `s3007_next` "Quét tiếp".
- **Chấp nhận**:
  - Một mã gồm cả booking và vé: thợ quét thì chỉ đổi booking, cổng quét thì chỉ đổi vé.
  - Bên khách thấy thay đổi trong < 2 giây.
  - Nút "Quét tiếp" cao 52dp.

---

## Thay đổi ở màn đã có

### S29.02 · Khối "Vào cửa" và nhãn trên thẻ thợ (S29.02-entry)
- Chỉ hiện khi `access.type = ticket`, đặt trên "Thợ nhận chụp ở đây".
  - Có vé bán qua app: giá theo loại vé, giờ mở cửa, "Bán bởi {chủ}", nút nhỏ "Mua vé".
  - Chưa bán qua app: "Giá tham khảo · cập nhật {ngày}", không có nút.
- Thẻ thợ:
  - Thợ tại điểm có `ptag` "Thợ tại điểm · miễn vé" (hoặc "miễn vé thợ") và được xếp trước.
  - Thợ khác có dòng "Cần vé cho bạn và thợ ≈ {giá}".
- **Chuỗi**: `s2902_entry` "Vào cửa", `s2902_buy` "Mua vé", `s2902_soldBy` "Bán bởi {org}", `s2902_refPrice` "Giá tham khảo · cập nhật {date}", `s2902_resident` "Thợ tại điểm · miễn vé", `s2902_needTickets` "Cần vé cho bạn và thợ ≈ {amount}".

### S04.03 · Vé vào cửa trong đơn (S04.03-entry)
- Thẻ "Vé vào cửa · {ngày}" có công tắc (bật sẵn) và bộ đếm cho vé của khách; vé cho thợ cố định 1, không có nếu thợ được miễn.
- Bảng tiền có thêm dòng "Vé vào cửa × n".
- Ghi chú hai bên nhận tiền: tiền buổi chụp chuyển cho thợ, tiền vé chuyển cho địa điểm.
- Tắt công tắc: thẻ đổi thành "Tự mua vé tại cổng ≈ {giá}".
- Điểm chỉ có giá tham khảo: hiện mục "Chi phí tại chỗ (không qua app)".
- **Chấp nhận**: một `createPayment` với hai dòng; thợ từ chối thì cả hai dòng được hoàn 100%.

### S05.02 · Mã gặp thợ và câu hỏi khi không quét (S05.02-pass, S05.02-askshot)
- Thẻ "Mã gặp thợ" hiện từ 24 giờ trước buổi chụp: QR, mã chữ, các vé đi kèm. Chạm vào để xem toàn màn hình với độ sáng tối đa.
- Timeline thêm bước "Đang chụp".
- Sheet "Buổi chụp có diễn ra không?" hiện ở giờ kết thúc + 24 giờ nếu chưa ai quét. Callable `answerShootHappened`. Chọn "Không diễn ra" → S18.01 với lý do điền sẵn.

### S06.01 · Quét mã khách (S06.01-scan)
- Thẻ buổi hôm nay có nút nhỏ "Quét mã khách" (bật từ 2 giờ trước giờ bắt đầu), dòng tình trạng vé của thợ, nhãn "Đang chụp" và nút "Đã chụp xong" (chỉ hiện sau khi đã quét).

### S11.02 · Chủ điểm đồng ý sự kiện (S11.02-venue-consent)
- Sheet cho chủ điểm: thông tin sự kiện, ô "Phí quản lý mỗi khách", hai nút "Từ chối" (chữ đỏ, mở sheet xác nhận có nút đỏ) và "Đồng ý". Callable `respondVenueConsent`.
- Khách thấy giá vé kèm dòng "gồm phí quản lý địa điểm {y}".
- S11.02 và S11.03 hiện dòng phí vào cửa: "Đã gồm vé vào cửa" hoặc "Chưa gồm vé vào cửa ≈ {x} · trả tại cổng".

### S11.04 · Vé vào cửa (S11.04-entry)
- Nhóm "Vé" gồm cả vé vào cửa: nhãn "Vé vào cửa", ngày tham quan, giờ mở cửa, số vé theo loại; không có nhóm chat.
- Trạng thái: "Đã vào 07:42"; "Ngày đóng cửa · đang hoàn 100%"; hết mốc huỷ.

### S12.01 · Ô Địa điểm (S12.01-venue)
- Ba lựa chọn bắt buộc: điểm có chủ quản lý / nơi có thu phí / nơi công cộng.
  - Nơi có thu phí: tên nơi, chọn "Đã gồm" hoặc "Chưa gồm" phí vào cửa, nếu chưa gồm thì nhập giá tham khảo.
  - Nơi công cộng: ô tick cam kết.
- Mọi host tick điều khoản tổ chức sự kiện. Lưu `Event.venue`.
- **Kiểm tra**: thiếu lựa chọn, thiếu lựa chọn gồm/chưa gồm, thiếu cam kết (nơi công cộng), hoặc chưa tick điều khoản → lỗi dưới ô.
- **Chuỗi**: `s1201_venue` "Địa điểm · bắt buộc", `s1201_venueManaged` "Điểm có chủ quản lý", `s1201_venuePaid` "Nơi có thu phí vào cửa", `s1201_venuePublic` "Nơi công cộng", `s1201_feeIncluded` "Đã gồm phí vào cửa", `s1201_feeNotIncluded` "Chưa gồm", `s1201_commitment` "Tôi tự chịu trách nhiệm xin phép theo quy định địa phương", `s1201_terms` "Tôi đồng ý điều khoản tổ chức sự kiện."

### S12.03 · Quản lý vé vào cửa (S12.03-entry)
- Sự kiện `type = entry`: chip ngày, KPI của ngày (đã bán / sức chứa, đã vào, doanh thu), bảng theo loại vé.
- "Đóng ngày này" (chữ đỏ) mở sheet xác nhận có nút đỏ, nêu số vé và tổng tiền sẽ hoàn. Nút chính "Quét mã".
- Sự kiện thường ở điểm có chủ: thêm dòng trạng thái đồng ý của địa điểm và phí quản lý.

### S09.02 · Cài đặt
- Thêm dòng "Tổ chức sự kiện / quản lý địa điểm" → S30.01 (đã là chủ sự kiện thì "Địa điểm của tôi" → S30.03).
- Nhân viên soát vé có thêm dòng "Soát vé · {địa điểm}" → S30.07.
