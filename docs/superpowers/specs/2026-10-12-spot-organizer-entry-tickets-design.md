# Chủ sự kiện & vé vào cửa (S30)

Ngày: 2026-10-12 · Trạng thái: thiết kế đã chốt với chủ dự án (brainstorm 2026-10-12) · Issue: #223 · Dựa trên: `2026-10-08-trending-spots-design.md` (S29, điểm chụp), spec chính `2026-10-01-remaining-screens.md` §3 (sự kiện S11–S12, vé có QR, `checkInRegistration`), `2026-10-06-payments-payouts-design.md` (trả 100% trước, giữ, chi theo mốc, hoa hồng M7), `2026-10-06-identity-verification-design.md` (S21.04 xác minh doanh nghiệp), `2026-10-05-provider-types-portfolio-jobs-design.md` (trạng thái `shot`, mốc 1), `2026-10-06-studio-members-design.md` (thợ được giao).

## 1. Mục tiêu

Nhiều điểm chụp đẹp thu vé vào cửa (Bãi đá sông Hồng: vé người lớn ≈ 70.000₫ trước 18h theo một bảng giá năm 2024, chưa xác nhận). Khách thuê thợ ở ngoài phải mua vé cho mình **và cho thợ**. Còn thợ đã đăng ký với địa điểm thì được miễn khoản này. Hiện app không cho ai biết chuyện đó trước.

Spec này làm ba việc:

1. **Cho cả hai bên biết phí vào cửa** trước khi đặt booking hoặc đăng ký sự kiện.
2. **Địa điểm là một chủ sự kiện.** Địa điểm có tài khoản, nhận quản lý điểm chụp, bán vé vào cửa qua dịch vụ thanh toán của app, xác nhận danh sách thợ tại điểm, và quét QR ở cổng.
3. **Sự kiện phải khai rõ địa điểm**: điểm có chủ quản lý, nơi có thu phí, hay nơi công cộng. Sự kiện cũng phải ghi phí vào cửa đã gồm hay chưa gồm trong giá. Tổ chức tại điểm có chủ thì cần chủ điểm đồng ý và có thể chịu phí quản lý.

Thêm vào đó, **booking cũng có QR**. Thợ quét mã của khách khi gặp nhau, và booking chuyển sang "Đang chụp".

## 2. Quyết định đã chốt

| # | Quyết định | Nguồn |
|---|---|---|
| E1 | Địa điểm **là một chủ sự kiện** (thu phí và quét vé), không thêm vai `venue` riêng. Loại host mới `organizer` dùng cho người tổ chức không phải thợ. | chủ dự án 2026-10-12 |
| E2 | Vé vào cửa vừa **đi kèm booking** (khi thuê thợ ngoài), vừa **bán lẻ** cho mọi khách tham quan. | chủ dự án |
| E3 | Thoả thuận giữa thợ tại điểm và địa điểm **nằm ngoài app**. App chỉ lưu danh sách do địa điểm xác nhận cùng quyền lợi miễn vé. | chủ dự án |
| E4 | Làm toàn bộ ở **Phase 1** (Firebase). Khi `BLAZE_ENABLED` còn tắt thì chạy trên emulator như các luồng tiền khác. | chủ dự án |
| E5 | Vé là **mã QR**, quét bằng camera điện thoại của chủ sự kiện hoặc nhân viên soát vé. Dùng lại `mobile_scanner` và luồng check-in của S12.03. | chủ dự án |
| E6 | Booking kèm vé thì **trả trong một lần thanh toán**: một mã VietQR, server tách thành nhiều khoản giữ. | chủ dự án |
| E7 | Vé vào cửa có **nhiều loại** (tối đa 6, mỗi loại gồm tên và giá). Khung giờ chỉ nằm trong tên loại vé, app không kiểm tra giờ vào. | chủ dự án |
| E8 | **Quét mã → "Đang chụp"**: thợ quét QR của khách thì booking chuyển sang `shooting`. "Đã chụp xong" → `shot` giữ như cũ. | chủ dự án |
| E9 | Sự kiện ở **nơi có thu phí nhưng chưa có chủ trên app**: host chỉ khai **"Đã gồm / Chưa gồm phí vào cửa"**, app báo cho hai bên. Không cần tải văn bản, không cần staff duyệt. | chủ dự án |
| E10 | Sự kiện ở **nơi công cộng**: host tick **cam kết** tự xin phép theo quy định địa phương, app lưu lời cam kết. Không có ngưỡng số người, không cần staff duyệt. | chủ dự án |
| E11 | Luật tiền, hoàn huỷ, liên hệ sau thanh toán, chỉ nhà cung cấp đã duyệt mới nhận đơn, số điện thoại không nằm trong `users/{uid}`: **giữ nguyên**. | CLAUDE.md |

## 3. Chủ sự kiện

### 3.1 Trở thành chủ sự kiện (S30.01)

- Mọi người dùng (khách hoặc thợ) đều xin được, từ **Hồ sơ → "Tổ chức sự kiện / quản lý địa điểm"**. S01.05 không thêm vai mới. Thợ vẫn tạo sự kiện bằng tư cách thợ như hiện nay; tư cách chủ sự kiện dành cho tổ chức.
- Cần nhập: tên tổ chức (3–60 ký tự), mô tả (≤ 300), ảnh đại diện. Số điện thoại phải đã xác minh (S21.01).
- **Sự kiện không thu phí**: chỉ cần những bước trên.
- **Bán vé có thu phí** (vé vào cửa, sự kiện có giá, phí quản lý): phải qua **xác minh doanh nghiệp** (S21.04, mã số thuế, `kind: company | household`) và có **tài khoản nhận tiền đứng tên doanh nghiệp** (S06.06). Chưa đủ thì nút tạo vé có thu phí hiện "Xác minh doanh nghiệp để bán vé".
- Callable `becomeOrganizer` ghi `organizers/{uid}` (`status = active`). Staff gỡ được tư cách này (`suspended`). Khi bị gỡ, sự kiện đang mở bị huỷ và hoàn 100%.

### 3.2 Nhận quản lý điểm chụp (S30.02)

- Chủ sự kiện chọn một điểm S29 (tìm theo tên), rồi gửi **minh chứng là ban quản lý** (giấy phép kinh doanh, hợp đồng thuê, quyết định giao quản lý). Staff duyệt bằng CLI `npm run spots -- claims` ở Phase 1, sau này chuyển lên web S23.
- Đây là chỗ duy nhất trong spec cần staff duyệt giấy tờ, vì người được duyệt sẽ quyết định giá vé, danh sách thợ và việc đồng ý cho sự kiện của người khác ở điểm đó. Nếu không duyệt thì ai cũng có thể chiếm một điểm.
- Mỗi điểm có **tối đa một** chủ quản lý (`spots.managedBy`). Đã có chủ thì yêu cầu mới bị chặn (`spot_managed`), và người gửi được hướng dẫn liên hệ hỗ trợ.
- Sau khi được duyệt, chủ sửa được: mô tả, mẹo, ảnh bìa, giờ mở cửa, thông tin vào cửa (§3.3) và thợ tại điểm (§3.4). Tên, toạ độ, bán kính và mùa vẫn chỉ staff sửa.

### 3.3 Thông tin vào cửa của điểm

`spots.access` cho biết điểm có thu vé hay không và giá tham khảo:

- `type: open | ticket`.
- `fees: [{label, amountVnd}]` (≤ 6), `note?` (≤ 120 ký tự, ví dụ "Gửi xe máy 5.000₫").
- `updatedAt`, `source: staff | organizer`.

Trên app hiện là **"Giá tham khảo · cập nhật {ngày}"**. Nếu điểm đang có **sự kiện vé vào cửa** đang mở (§4) thì giá lấy từ các loại vé của sự kiện đó, và có nút "Mua vé".

Staff nhập `access` cho điểm chưa có chủ (CLI `npm run spots -- access`), để khách và thợ vẫn biết phí ngay cả khi địa điểm chưa dùng app.

### 3.4 Thợ tại điểm (S30.03)

`spots/{spotId}/residents/{providerId}`:

| Trường | Ghi chú |
|---|---|
| `waivesProvider` | Thợ được vào không mất vé |
| `waivesGuests` | Khách của thợ được vào không mất vé |
| `maxGuests?` | Số khách tối đa được miễn mỗi lần |
| `validUntil?` | Hết hạn thì tự hết hiệu lực (job ngày) |
| `addedAt`, `addedBy` | |

- Chủ điểm tìm thợ theo tên, @username hoặc link hồ sơ. Chỉ thêm được nhà cung cấp `acceptsOrders` (thợ hoặc studio), tối đa **50** người mỗi điểm.
- Thợ nhận thông báo `spot_resident_added`, và tự rời danh sách được.
- Công khai cho mọi người đọc, vì nhãn "Thợ tại điểm · miễn vé" cần dữ liệu này. Chỉ server ghi.
- Ai trả tiền cho ai giữa thợ và địa điểm thì app không biết và không xử lý (E3).

### 3.5 Nhân viên soát vé (S30.06)

- Chủ mời tối đa **10** tài khoản qua số điện thoại hoặc @username. Người được mời chấp nhận trong 72 giờ.
- Nhân viên chỉ mở được **S30.07 Quét mã** và xem số người đã vào trong ngày. Họ không thấy doanh thu, không thấy số điện thoại khách, và không sửa được gì.
- Lưu ở `organizers/{uid}/gate_staff/{staffUid}` (`status: invited | active | removed`). Functions kiểm tra tư cách này khi quét.

## 4. Vé vào cửa

### 4.1 Sự kiện `type = "entry"`

Dùng lại `events/{eventId}` và thêm `type: "entry"`. Ràng buộc riêng:

| Trường | Ghi chú |
|---|---|
| `host` | `{type: "organizer", id}`, và phải là chủ quản lý của `spotId` |
| `spotId` | bắt buộc |
| `startAt`, `endAt` | khoảng bán vé (≤ 180 ngày), ví dụ cả mùa hoa |
| `closedWeekdays?` | ngày nghỉ trong tuần |
| `closedDays?` | ngày nghỉ lẻ (≤ 30) |
| `openHours` | `{start, end}` giờ địa phương, chỉ để hiển thị |
| `ticketTypes` | `[{id, name, price}]`, 1–6 loại; `price` là số nguyên VND > 0 |
| `dailyCapacity?` | rỗng = không giới hạn |
| `refundCutoffHours` | mặc định 48 |

- **Không có:** `capacity` tổng, `hashtag`, nhóm chat, đánh dấu lịch bận của host, FAQ.
- `entry_days/{eventId}_{day}` (chỉ server ghi, ai cũng đọc): `{sold, checkedIn}`. Dùng để kiểm tra sức chứa và hiện "còn chỗ".
- Chủ **đóng một ngày** được (mưa bão, sự cố): mọi vé của ngày đó được hoàn 100% và khách nhận thông báo. Chủ **huỷ cả sự kiện** thì hoàn 100% mọi vé chưa dùng.
- Sửa giá chỉ áp dụng cho đơn mới. Không xoá được loại vé đã bán, chỉ ẩn được.

### 4.2 Mua vé lẻ (S30.05)

Từ S29.02 bấm "Mua vé". Màn có:

- Chip ngày: các ngày mở trong 14 ngày tới, cộng "Chọn ngày". Ngày đã đủ chỗ thì mờ, kèm chữ "Hết vé".
- Bộ đếm cho từng loại vé, tổng tối đa **10 vé** mỗi đơn.
- Dòng "Huỷ trước {48} giờ hoàn 100%".
- Nút chính "Thanh toán {tổng}", đi tiếp qua S04.04 (VietQR hoặc ví).

Registration dùng chung `events/{id}/registrations/{regId}` và thêm các trường: `visitDay`, `items: [{ticketTypeId, name, price, qty}]`, `bookingId?`. `quantity` = tổng `qty`. Giới hạn 1–4 vé của sự kiện thường không áp cho vé vào cửa.

### 4.3 Hoàn và chi tiền

- **Khách huỷ** trước ngày tham quan (00:00 giờ địa phương) từ `refundCutoffHours` trở lên: hoàn 100%. Sau mốc đó: không hoàn.
- **Chủ đóng ngày hoặc huỷ sự kiện**: hoàn 100%.
- **Chi cho chủ**: theo **từng ngày tham quan**. Khoản giữ của vé ngày D được nhả lúc D + 1 ngày + 48 giờ (cửa sổ khiếu nại), nếu không có khiếu nại. Không đợi cả sự kiện `completed`.
- **Hoa hồng sàn**: dùng cấu hình M7, mặc định **0%**, có loại riêng `entry_ticket` và `venue_fee`. Chủ là doanh nghiệp nên tự xuất hoá đơn cho khách; nền tảng **không khấu trừ thuế thay** (M8 chỉ áp cho thợ cá nhân).

## 5. Mua vé kèm booking

### 5.1 Khi nào có dòng vé

Áp dụng khi khách đặt thợ cho một booking có `spotId`, hoặc khi địa điểm booking nằm trong bán kính của điểm có `access.type = ticket`. Có hai trường hợp:

- **Điểm có sự kiện vé vào cửa đang mở cho ngày đó**: S04.03 thêm dòng **"Vé vào cửa · {ngày}"**, bật sẵn, kèm bộ đếm theo loại vé. Mặc định là 1 vé loại đầu tiên cho khách, cộng 1 vé cho thợ.
  - Thợ có `waivesProvider`: không có vé cho thợ, hiện "Thợ tại điểm · miễn vé".
  - Thợ có `waivesGuests`: không có vé cho khách (trong giới hạn `maxGuests`).
  - Khách tắt được dòng này, khi đó dòng đổi thành "Tự mua vé tại cổng ≈ {giá}".
- **Điểm chỉ có giá tham khảo** (không bán qua app): S04.03 hiện mục **"Chi phí tại chỗ (không qua app)"**, ví dụ "Vé vào cửa ≈ 70.000₫ × 2 (bạn và thợ)", và không thu tiền.

### 5.2 Một lần thanh toán, nhiều dòng

Thêm `Payment.lines`:

```
lines: [{kind: booking | entry_ticket | event_ticket | venue_fee,
         subjectType, subjectId, payeeId, amount}]
```

- `Payment.amount = Σ lines.amount`. Khoản cũ chỉ có một subject được hiểu là một dòng, nên dữ liệu cũ đọc ngược được.
- `createPayment` cho booking nhận thêm `entry: {eventId, visitDay, items}`. Server tạo registration `held` (giữ chỗ trong ngày, cùng hạn với Payment) và thêm dòng `entry_ticket`.
- Webhook `paid`: mỗi dòng được đánh dấu riêng (booking theo luồng cũ; registration thành `paid` và sinh mã), và **mỗi dòng có một khoản giữ riêng** với bên nhận riêng.
- Chuyển thiếu hoặc quá hạn: cả đơn hết hạn, mọi registration `held` được nhả (luồng §3.3 của spec thanh toán không đổi).
- Tổ chức trung gian phải chi được cho **nhiều bên nhận** từ cùng một khoản thu hộ. Điều kiện này được thêm vào danh sách chọn đối tác (spec thanh toán §10).

### 5.3 Huỷ

| Ai huỷ | Booking | Vé đi kèm |
|---|---|---|
| Thợ từ chối, hết hạn nhận, hoặc thợ huỷ | hoàn 100% | **hoàn 100%** (lý do đi không còn) |
| Khách huỷ booking | theo luật booking | theo luật vé (§4.3). Sheet huỷ có lựa chọn "Giữ vé vào cửa", vé vẫn dùng được |
| Chủ điểm đóng ngày | booking giữ nguyên, thợ và khách nhận thông báo | hoàn 100% |

## 6. Mã của khách và "Đang chụp"

### 6.1 Một mã cho mỗi đơn

- Mỗi registration đã `paid` và mỗi booking đã thanh toán có một **mã vào cửa** (`pass`). Booking kèm vé thì **dùng chung một mã**.
- `passes/{code}` (chỉ server đọc và ghi): `{customerId, day, bookingId?, registrationIds[]}`.
- `code` gồm 8 ký tự từ bảng `23456789ABCDEFGHJKMNPQRSTVWXYZ`, hiển thị dạng `VE-7K2Q-0420` (giữ định dạng `ticketCode` hiện tại; registration của sự kiện thường vẫn dùng `ticketCode` làm mã).
- Khách xem mã ở **"Vé của tôi" (S11.04)** và ở chi tiết booking (S05, mục "Mã gặp thợ"). Màn hiện QR lớn, mã chữ phía dưới và độ sáng màn hình tăng lên. Màn này dùng được khi không có mạng (QR được lưu sẵn trên máy).
- **Chỉ khách đọc được mã của mình**: bản sao nằm ở `bookings/{id}/private/pass` và `registrations/{regId}/private/pass`, rules chỉ cho khách đó đọc. Thợ, host và nhân viên không đọc được. Nếu đọc được thì họ tự "quét" mà không cần gặp khách, và `shooting` mất giá trị làm bằng chứng. `ticketCode` cũ của sự kiện chuyển vào chỗ này: danh sách người tham gia ở S12.03 chỉ hiện 4 ký tự cuối.

### 6.2 Quét: server quyết định theo người quét

Callable `scanPass({code})`. `checkInRegistration` cũ trở thành lớp bọc gọi sang hàm này.

| Người quét | Kết quả |
|---|---|
| Thợ của booking (studio: thợ được giao) | booking `upcoming → shooting`, ghi `checkedInAt` |
| Chủ hoặc nhân viên soát vé của sự kiện vé vào cửa | registration của ngày đó: `checkedInAt` ("Đã vào") |
| Chủ sự kiện thường (thợ, chủ sự kiện, staff nền tảng) | registration: `checkedInAt` (người tham gia "Đang chụp" / "Đã vào") |
| Chủ hoặc nhân viên của điểm có quản lý, quét vé sự kiện có `venue.spotId` thuộc điểm đó | registration: `gateCheckedInAt` (vào cổng bằng vé sự kiện, §7.2) |
| Người khác | lỗi `not_your_pass`, không đổi gì |

Một mã có thể khớp nhiều phần (ví dụ thợ quét một mã gồm booking và vé). Mỗi người quét chỉ cập nhật phần thuộc về mình.

**Lỗi khi quét** (hiện rõ trên S30.07, kèm rung):

| Mã lỗi | Thông báo |
|---|---|
| `already_checked_in` | "Đã vào lúc 07:42" |
| `wrong_day` | "Vé ngày CN 18/10" |
| `too_early` | "Mở quét từ 05:00" |
| `refunded` | "Vé đã hoàn" |
| `not_your_pass` | (người quét không có quyền với mã này) |

**Khung giờ quét:**
- Booking: trong ngày diễn ra, từ 2 giờ trước giờ bắt đầu.
- Vé vào cửa: trong ngày tham quan.
- Sự kiện thường: từ 2 giờ trước `startAt` đến `endAt`.

Nếu camera không quét được, nhập tay **8 ký tự** dưới QR. Kết quả quét hiện ngay; bên khách thấy thay đổi trong vòng < 2 giây.

### 6.3 Trạng thái `shooting`

Spec này sửa luồng trạng thái của spec 2026-10-05 §4 như sau:

```
accepted ──(T-24h)──▶ upcoming ──(thợ quét mã)──▶ shooting ──(thợ "Đã chụp xong")──▶ shot
upcoming ──(end + 24h, không ai quét)──▶ hỏi khách "Buổi chụp có diễn ra không?"
    ├─ "Có" hoặc không trả lời trong 48 giờ ──▶ shot (shotAt = end)
    └─ "Không" ──▶ mở khiếu nại S18, mốc 1 bị giữ
```

- Nút "Đã chụp xong" chỉ bật khi booking đã ở `shooting`.
- Việc tự chuyển `shot` lúc `end + 24h` (luồng cũ) được thay bằng câu hỏi gửi cho khách ở trên.
- `shooting` không ảnh hưởng hoàn tiền: luật huỷ trước buổi chụp tính theo giờ bắt đầu như cũ, và đã `shooting` thì không huỷ được nữa (chỉ khiếu nại).
- `BookingStatus` thêm `shooting`. `Chat.bookingStatus` sao chép trạng thái này như các trạng thái khác.

## 7. Địa điểm khi tạo sự kiện

### 7.1 Ô "Địa điểm" ở S12.01 (bắt buộc)

`Event.venue`:

```
venue: {
  kind: managed_spot | paid_place | public,
  spotId?,                                  # bắt buộc khi managed_spot
  entryFee: {included: bool, amountVnd?},   # "Đã gồm" / "Chưa gồm ≈ …"
  commitmentAt?,                            # public: lúc tick cam kết
  termsVersion                              # điều khoản tổ chức sự kiện đã chấp nhận
}
```

| Loại | Ví dụ | Điều kiện để đăng |
|---|---|---|
| `managed_spot`: điểm S29 có chủ quản lý trên app | Bãi đá sông Hồng (đã có tài khoản) | Host chính là chủ điểm: không cần gì thêm. Host là người khác: cần **chủ điểm đồng ý** (§7.2). |
| `paid_place`: nơi có thu phí nhưng chưa có chủ trên app | khu du lịch, công viên có vé | Host chọn **"Đã gồm phí vào cửa"** hoặc **"Chưa gồm phí vào cửa"**; nếu chưa gồm thì nhập số tiền tham khảo. Nếu nơi đó là một điểm S29 có `access` thì số tiền được điền sẵn. |
| `public`: nơi công cộng không thu phí | Hồ Tây, phố đi bộ | Host tick **"Tôi tự chịu trách nhiệm xin phép theo quy định địa phương"**. App lưu `commitmentAt`. |

**Điều kiện chung:**
- Sự kiện có thu phí: host phải là nhà cung cấp `acceptsOrders`, chủ sự kiện đã xác minh doanh nghiệp, hoặc nền tảng.
- Mọi host chấp nhận **điều khoản tổ chức sự kiện** (`termsVersion` được lưu theo sự kiện).
- Staff gỡ được sự kiện vi phạm (S20, S23), và mọi vé được hoàn 100%.
- Không có bước tải giấy tờ hay staff duyệt sự kiện (E9, E10).

### 7.2 Tổ chức tại điểm có chủ quản lý

- Sự kiện ở trạng thái `draft`, chờ `venueConsent: pending → accepted | declined | expired` (hết hạn sau **72 giờ**, theo cơ chế `hostConsent`). Chủ điểm nhận thông báo `event_venue_requested`. Chạm vào thì mở S11.02 với hai nút Chấp nhận / Từ chối.
- Khi chấp nhận, chủ điểm có thể đặt **phí quản lý mỗi khách** (`venueFeePerGuest`, VND, có thể bằng 0). Phí này đã bao gồm việc khách của sự kiện vào cổng: nhân viên quét vé sự kiện ở cổng (§6.2), khách không phải mua vé vào cửa riêng.
- Mỗi registration trả tiền thêm một dòng `venue_fee = venueFeePerGuest × quantity`, bên nhận là chủ điểm. Dòng này chi theo luật vé sự kiện (sau khi sự kiện `completed`). Khách thấy "Giá vé {x} · gồm phí quản lý địa điểm {y}".
- Chỉ áp dụng khi chủ điểm đã xác minh doanh nghiệp. Nếu chưa, phí quản lý chỉ có thể bằng 0.
- Nếu host sửa ngày, giờ hoặc sức chứa sau khi đã được đồng ý, sự kiện quay về `pending`.
- Phí trọn gói cho cả sự kiện (host trả cho địa điểm) **không làm** trong spec này: host và địa điểm tự thoả thuận ngoài app.

## 8. Ai thấy gì về phí vào cửa

| Nơi | Khách | Thợ / host |
|---|---|---|
| S29.02 Trang điểm | Khối "Vào cửa": giá theo loại, giờ mở cửa, "Mua vé" hoặc "Giá tham khảo · cập nhật {ngày}" | như khách |
| Thẻ thợ ở S29.02 và S02.06 (khi đang lọc theo điểm) | "Thợ tại điểm · miễn vé", hoặc "Cần vé cho bạn và thợ ≈ {x}" | — |
| S04.03 | dòng vé (§5.1) hoặc "Chi phí tại chỗ (không qua app)" | — |
| S29.04 Mở lịch tại điểm | — | "Điểm này thu vé ≈ {x}/người. Bạn chưa thuộc thợ tại điểm, khách sẽ mua vé cho bạn." |
| Chi tiết booking (S05 / S06) | "Đã gồm vé vào cửa cho bạn và thợ" / "Tự mua tại cổng ≈ {x}" | "Khách đã mua vé cho bạn" / "Bạn được miễn vé" / "Khách tự mua tại cổng" |
| S11.02, S11.03, vé | "Đã gồm vé vào cửa" hoặc "Chưa gồm vé vào cửa ≈ {x} · trả tại cổng" | — |
| S12.01, S12.03 | — | nhắc lại lựa chọn `entryFee`; S12.03 hiện thêm trạng thái đồng ý của địa điểm và phí quản lý |

## 9. Server

### 9.1 Domain (`packages/domain`)

| File | Nội dung |
|---|---|
| `entry_tickets.ts` | `validateEntryEvent`, `openDays(event, range)`, `priceItems(ticketTypes, items)`, `assertDailyCapacity`, `entryRefund(visitDay, now, cutoff)`, `entryReleaseAt(visitDay)` |
| `spot_residency.ts` | `waiverFor(resident, now)` → `{provider, guests, maxGuests}`, và `bookingEntryDefaults(...)` |
| `payment_lines.ts` | `buildLines`, `assertLinesSum`, `holdsFor(lines)`, `refundPlan(lines, cancelBy)` theo bảng §5.3 |
| `pass_scan.ts` | `resolveScan(pass, scanner, now)` → các thay đổi được phép hoặc mã lỗi §6.2, gồm khung giờ |
| `booking_state.ts` (sửa) | thêm `shooting`, câu hỏi khi không quét, chặn "Đã chụp xong" khi chưa `shooting` |
| `event_venue.ts` | `validateVenue`, luật `venueConsent`, `venueFeeLine` |

### 9.2 Callables (`asia-southeast1`)

| Nhóm | Callables |
|---|---|
| Chủ sự kiện | `becomeOrganizer`, `claimSpot`, `reviewSpotClaim` (staff), `updateManagedSpot`, `saveResident`, `removeResident`, `inviteGateStaff`, `respondGateStaff`, `removeGateStaff` |
| Vé | `createEvent` / `updateEvent` nhận `type = entry` và `venue`; `closeEntryDay`; `registerEntry`; `respondVenueConsent` |
| Thanh toán | `createPayment` nhận thêm `entry` |
| Quét và booking | `scanPass`; `answerShootHappened` (câu hỏi "Buổi chụp có diễn ra không?" của khách) |

Lỗi mới: `spot_managed`, `not_spot_manager`, `day_closed`, `sold_out_day`, `not_your_pass`, `wrong_day`, `too_early`, `already_checked_in`, `venue_consent_required`, `business_required`.

### 9.3 Job

- `releaseEscrow` thêm nhả theo ngày tham quan.
- `expireResidents` chạy hằng ngày (gộp vào job ngày đã có, không thêm lịch mới).
- `askShootHappened`: gộp vào cron giờ `closeEvents` / booking hiện có.
- `expireVenueConsent`: gộp vào cron giờ.

### 9.4 Rules và index

**Rules:**
- `organizers/{uid}`: ai cũng đọc; chỉ server ghi.
- `organizers/{uid}/gate_staff/*`: chủ và nhân viên đó đọc.
- `spots/{id}/residents/*`: ai cũng đọc.
- `spot_claims/*`: người gửi và staff đọc. Minh chứng nằm ở Storage `spot_claims/{id}/…`, chỉ người gửi và staff đọc.
- `entry_days/*`: ai cũng đọc.
- `passes/*`: không client nào đọc.
- `*/private/pass`: chỉ khách sở hữu đọc.
- Mọi collection mới: chỉ server ghi.
- Nhân viên soát vé không đọc được `registrations/*/private/contact`.

**Index:**
- `events(type, spotId, status)`
- `events(venue.spotId, venueConsent)`
- collection group `registrations(visitDay, status)`
- `spot_claims(status, createdAt)`

## 10. Màn hình và mock

| Mã | Màn | Route | Vai trò |
|---|---|---|---|
| S30.01 | Trở thành chủ sự kiện | `/organizer/apply` | mọi người dùng |
| S30.02 | Nhận quản lý điểm chụp | `/organizer/spots/claim` | chủ sự kiện |
| S30.03 | Quản lý điểm: thông tin vào cửa, giờ mở cửa, thợ tại điểm | `/organizer/spots/:spotId` | chủ sự kiện |
| S30.04 | Tạo/sửa vé vào cửa: loại vé, khoảng ngày, ngày nghỉ, sức chứa/ngày | `/organizer/entry/new`, `/organizer/entry/:eventId/edit` | chủ sự kiện |
| S30.05 | Mua vé vào cửa: ngày và số lượng theo loại | `/spots/:spotId/tickets` | khách |
| S30.06 | Nhân viên soát vé | `/organizer/gate-staff` | chủ sự kiện |
| S30.07 | Quét mã (camera, nhập tay, kết quả, số đã vào hôm nay) | `/scan` | chủ, nhân viên soát vé, thợ |

**Biến thể ở màn đã có:**

| Mã | Thay đổi |
|---|---|
| S29.02-entry | khối Vào cửa, nhãn miễn vé / cần vé trên thẻ thợ |
| S04.03-entry | dòng vé vào cửa, chi phí tại chỗ |
| S05-pass | "Mã gặp thợ" trong chi tiết booking, câu hỏi "Buổi chụp có diễn ra không?" |
| S06-scan | nút "Quét mã khách" trên booking hôm nay, trạng thái "Đang chụp" |
| S11.02-fee / S11.03-fee | dòng phí vào cửa, phí quản lý |
| S11.02-venue-consent | nút Chấp nhận / Từ chối cho chủ điểm |
| S11.04-entry | vé vào cửa trong "Vé của tôi" |
| S12.01-venue | ô Địa điểm, phí vào cửa, cam kết |
| S12.03-entry | thống kê theo ngày, đóng ngày |
| S09.02 | lối vào "Tổ chức sự kiện / quản lý địa điểm" |

Trong S30 chỉ S30.07 có camera. Mỗi màn có đúng một nút chính: "Gửi yêu cầu" (S30.01, S30.02), "Lưu" (S30.03, S30.04), "Thanh toán {tổng}" (S30.05), "Mời" (S30.06). S30.07 không có nút gradient. Đóng ngày, gỡ thợ, gỡ nhân viên dùng sheet xác nhận có nút đỏ.

Đồng bộ: `docs/design/ui-mock.html` (#223 vẽ), bảng mã §2 của spec chính, `lib/core/screen_codes.dart`, `specs/screens/` (file mới `organizer.md`).

## 11. Test

**Domain:**
- Ngày mở/nghỉ, sức chứa theo ngày, giá nhiều loại vé, tổng vé > 10.
- Hoàn vé trước và sau mốc 48 giờ; chủ đóng ngày.
- Miễn vé: thợ có hoặc không `waivesProvider`, `waivesGuests` có `maxGuests`, quyền lợi hết hạn.
- Tách dòng thanh toán; kế hoạch hoàn theo từng ai huỷ (§5.3).
- Quét: đúng người, sai người, sai ngày, quá sớm, lần hai, vé đã hoàn; một mã gồm booking và vé, thợ quét chỉ đổi booking.
- `shooting`: "Đã chụp xong" bị chặn khi chưa quét; khách trả lời Có / Không / không trả lời.
- `venue`: thiếu cam kết, thiếu `entryFee`, `managed_spot` chưa được đồng ý, đồng ý hết hạn, sửa trường quan trọng thì quay về `pending`.

**Functions:**
- Hai khách mua chỗ cuối cùng của một ngày cùng lúc: một người nhận `sold_out_day`.
- Một thanh toán VietQR cho booking kèm vé tạo ra hai khoản giữ với hai bên nhận.
- Thợ từ chối: hoàn cả hai dòng.
- Đóng ngày: hoàn vé, booking không đổi.
- Nhả tiền vé đúng ngày tham quan + 1 ngày + 48 giờ.
- Hai người cùng xin quản lý một điểm: người thứ hai nhận `spot_managed`.
- Nhân viên soát vé quét vé sự kiện của điểm mình (được) và của điểm khác (`not_your_pass`).

**Rules (viết kèm, CI chạy):**
- Không client nào đọc `passes`; thợ và host không đọc được `private/pass` của khách.
- Nhân viên soát vé không đọc được thông tin liên hệ của khách.
- Minh chứng nhận quản lý điểm chỉ người gửi và staff đọc.

**Flutter:**
- S30.01–S30.07.
- Các biến thể §10.
- Màn mã dùng được khi không có mạng.
- Kết quả quét hiện trong < 2 giây.
- Kiểm tra ở bề rộng 320 dp, cỡ chữ 1,3×, giao diện tối và sáng.

## 12. Chi phí Google (đơn giá `2026-10-07-google-cloud-costs.md`)

- Trang điểm: thêm 2–3 lượt đọc (sự kiện vé vào cửa, `entry_days` của các ngày đang xem, `residents` ≤ 50, đọc một lần).
- Mua vé: khoảng 6 lượt đọc/ghi (transaction `entry_days`, registration, payment, pass).
- Quét mã: 3–4 lượt đọc/ghi mỗi lần.
- Job: không thêm lịch mới (gộp vào job ngày và cron giờ có sẵn).
- Ước tính: **(b) 1.000 MAU ≈ +$0,2/tháng; (c) 10.000 MAU ≈ +$1,5/tháng**, giả sử 20% người dùng mua vé hoặc được quét 2 lần/tháng. Dưới ngưỡng $5.

## 13. Cần xác nhận trước khi ra mắt

| Việc | Mặc định trong spec | Ai xác nhận |
|---|---|---|
| Nội dung cam kết "tự xin phép theo quy định địa phương" và điều khoản tổ chức sự kiện | bản nháp do plan viết, có `termsVersion` | luật sư |
| Nền tảng có phải xin phép hay chịu trách nhiệm liên đới khi bán vé cho bên thứ ba | không. Chủ sự kiện là người bán, nền tảng là kênh và giữ tiền qua tổ chức trung gian | luật sư, kế toán |
| Tổ chức trung gian chi được cho nhiều bên nhận từ một khoản thu | là điều kiện chọn đối tác (spec thanh toán §10) | chủ dự án khi chọn đối tác |
| Nghị định 144/2020 (biểu diễn nghệ thuật) có áp cho photo walk / mini session hay không | không áp; sự kiện có biểu diễn thuộc trách nhiệm host (cam kết) | luật sư |

## 14. Câu hỏi còn mở (đã có mặc định)

| Câu hỏi | Mặc định |
|---|---|
| Số vé tối đa mỗi đơn | 10 |
| Thợ tại điểm tối đa mỗi điểm / nhân viên soát vé tối đa mỗi chủ | 50 / 10 |
| Hạn để chủ điểm đồng ý sự kiện của người khác | 72 giờ |
| Mở quét trước giờ bắt đầu | 2 giờ |
| Khách không trả lời "Buổi chụp có diễn ra không?" | sau 48 giờ coi như có (`shot`) |
| Vé đi kèm booking khi khách huỷ booking | theo luật vé, có lựa chọn giữ vé |

## 15. Ngoài phạm vi

- Phí trọn gói host trả cho địa điểm.
- Kiểm tra khung giờ của loại vé lúc vào cổng.
- Sơ đồ chỗ ngồi.
- Bán vé qua kênh khác.
- Màn chủ sự kiện trên web (để Phase 1.5, #161).
- Thu tiền thợ tại điểm trả cho địa điểm (E3).
- Bản đồ mật độ và timeline check-in (#213, Phase 2).
