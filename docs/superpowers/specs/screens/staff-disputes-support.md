# S23 · Khiếu nại & hộp thư hỗ trợ (#165)

- **Issue:** #165, epic #83. **Ngày:** 2026-10-08. **Trạng thái:** chờ chủ dự án duyệt.
- **Dựa trên:** `../2026-10-08-dashboard-web-design.md` ("spec dashboard": quyền, `audit_log`, `getSensitiveFileUrl`, `staff_approvals` §5.4, mẫu hàng đợi), spec chính §3i.1 (S18), plan `../../plans/2026-10-07-s18-disputes-help.md` (#142, chưa merge; gọi là "plan S18"), `../2026-10-06-delivery-preview-unlock-design.md` (hai mốc tiền), `./staff-money.md` §2 (ngưỡng hai người).
- **Mock:** `docs/design/dashboard-mock.html#S23.01`, `#S23.06`.

## 0. Quyết định

| # | Quyết định | Nguồn |
|---|---|---|
| K1 | Quyết định khiếu nại: `admin`, `support`. `finance` chỉ xem số tiền, trạng thái, kết quả; không xem bằng chứng, lời kể hay hội thoại. `sales` không thấy khiếu nại. | spec dashboard §4.2 |
| K2 | Khiếu nại có số tiền hoàn từ **10.000.000₫** cần người thứ hai (admin hoặc support) qua `staff_approvals` (`kind: dispute_resolve`); cùng ngưỡng với thao tác tiền của #163. | luật M2 của #163 áp cho mọi tiền ra |
| K3 | Staff đọc được **chat booking** giữa khách và thợ khi xử lý một khiếu nại đang mở của chính booking đó, chỉ đọc, mỗi lần mở ghi `audit_log` (`dispute.chat_view`). Không đọc chat nào khác. | thoả thuận về dịch vụ thường nằm trong chat |
| K4 | Tin nhắn staff gửi người dùng ký "Hỗ trợ", không lộ tên hay uid staff: tin nhắn lưu `senderId: null`, `senderRole: 'staff'`; ai gửi nằm ở `audit_log`. Đổi so với plan S18 (nếu plan S18 ghi uid staff vào `senderId`). | riêng tư của staff |
| K5 | Hộp thư có **nhận xử lý** (`assigneeId`, chỉ staff thấy) và **ghi chú nội bộ** (`support_threads/{id}/staff_notes`, client không đọc được) để hai người không trả lời trùng và bàn giao ca được. Không có mẫu câu trả lời ở đợt này. | đội nhỏ, nhiều ca |
| K6 | "Huỷ phần bàn giao khi trễ hạn" là việc của khách trong app, làm ở issue Phase 1 **#207** (blocked by #152). S23.01 chỉ hiện cờ "Giao trễ hạn". | chủ dự án 2026-10-08 |
| K7 | Sự kiện do nền tảng tổ chức không có chat hỏi trước (O2, 2026-10-06), nên S23.06 chỉ có hai loại hội thoại: `help` và `dispute` (bỏ "hỏi trước của sự kiện nền tảng" khỏi mô tả S23.06). | spec chính §3.7 |

## 1. Màn và mã

| Mã | Màn | Route |
|---|---|---|
| S23.01 | Khiếu nại: hàng đợi và trang chi tiết (bằng chứng, hai mốc tiền, hội thoại ba bên, quyết định thả / hoàn / chia) | `/staff/disputes`, `/staff/disputes/:id` |
| S23.06 | Hộp thư hỗ trợ: hội thoại trợ giúp và hội thoại khiếu nại | `/staff/inbox`, `/staff/inbox/:threadId` |

Thanh bên nhóm "Hàng đợi": Khiếu nại · Hộp thư. Thẻ S23.09: khiếu nại đang mở (đỏ khi quá 72 giờ), hội thoại chờ trả lời (đỏ khi quá 12 giờ). Ô "Tìm theo mã" nhận mã khiếu nại `#K7Q2` (4 ký tự cuối id, `disputeCode` của plan S18), id khiếu nại hoặc id booking có khiếu nại.

## 2. S23.01 · Khiếu nại

### 2.1 Hàng đợi `/staff/disputes`

- Tab **Đang mở** (`status = open`) · **Đã có kết quả** (30 ngày).
- Bảng: mã (`#K7Q2`), chủ thể (booking: "{thợ} · {gói}", vé: tên sự kiện), lý do (nhãn từ `DISPUTE_REASONS`), số tiền đang giữ, mở lúc + tuổi, trạng thái hội thoại (chip "Chờ hỗ trợ" khi `awaitingStaff`, "Thợ chưa giải trình" khi thợ chưa nhắn sau 24 giờ), cờ "Giao trễ hạn" (§2.3).
- Sắp xếp: quá hạn trước, rồi cũ nhất. Bấm dòng mở trang chi tiết (không dùng `DetailPane`, vì khiếu nại cần nhiều chỗ).
- **Quá hạn:** mở quá 72 giờ chưa có kết quả.

### 2.2 Chi tiết `/staff/disputes/:id`

Ba cột trên desktop (≥ 1280 px; 1024–1279 px thì cột hội thoại xuống dưới):

1. **Sự việc** (trái):
   - Mã, lý do, lời kể của khách (nguyên văn), mở lúc, ai mở (`customer`; `provider` khi thợ mở vì hết lượt sửa, plan bàn giao).
   - **Bằng chứng:** tối đa 5 ảnh (`SecureFileViewer`, `kind: dispute_evidence`).
   - **Booking:** gói, ngày giờ, địa điểm, giá, trạng thái hiện tại và dòng thời gian (`requested → accepted → shot → delivered → approved…`), `deliveryDays`, số vòng sửa đã dùng, số ảnh mẫu đã giao. Vé: sự kiện, giờ, đã check-in hay chưa.
   - Nút phụ "Xem chat booking" (K3) mở một ngăn chỉ đọc bên phải; vé không có nút này.
2. **Tiền** (giữa):
   - Bảng mốc: mốc 1 (sau buổi chụp) và mốc 2 (sau duyệt bàn giao), mỗi mốc số tiền và trạng thái (đang giữ / đang khiếu nại / đã chuyển / đã chi); mốc bị khiếu nại tô viền. Payment không có mốc (vé, booking cũ): một dòng "toàn bộ".
   - **Số tiền khiếu nại giữ** (`amountHeld`), đã hoàn trước đó (nếu có).
   - Hai bên: khách (số booking, số khiếu nại đã mở), thợ (loại, số buổi đã xong, khiếu nại thua trong 90 ngày, đánh giá cà chua/gạch), link sang S23.04 của thợ.
   - **Quyết định** (chỉ admin, support; finance thấy phần này ở dạng chỉ đọc sau khi có kết quả): ba lựa chọn "Thả cho thợ" (`release`), "Hoàn cho khách" (`refund`), "Chia" (`split`, ô phần trăm hoàn 1–99). Ngay dưới hiện số tiền tính sẵn theo plan S18 Decision 7: `refundAmount = floor(held × % / 100)`, `releaseAmount = held − refundAmount`. Ô ghi chú 5–500 ký tự (gửi cho hai bên cùng kết quả). Nút chính **"Gửi quyết định"** → `DecisionDialog` tóm tắt "Hoàn {x} cho {khách}, chuyển {y} cho {thợ}" → `resolveDispute`. Hoàn từ 10 triệu: nút thành "Gửi duyệt lần hai" (K2).
   - Sự kiện do nền tảng tổ chức: "Thả" nghĩa là nền tảng giữ (`provider = platform`), nhãn đổi thành "Giữ cho nền tảng".
3. **Hội thoại ba bên** (phải): tin nhắn của khách, thợ, hệ thống, hỗ trợ (chip vai trò, thời gian); ô trả lời ký "Hỗ trợ" (§3.3); tab "Ghi chú nội bộ" (K5). Hội thoại đóng khi có kết quả (plan S18 Decision 8).

### 2.3 Cờ "Giao trễ hạn"

Booking `shot` có `now > shotAt + deliveryDays` và chưa `delivered`: chip đỏ "Giao trễ hạn {n} ngày" ở hàng đợi và phần Sự việc. Khi #207 xong, khách tự huỷ phần bàn giao được; staff vẫn có thể chọn "Hoàn cho khách" với số tiền của mốc 2.

### 2.4 Trạng thái, chấp nhận

- **Trạng thái:** trống "Không có khiếu nại nào đang mở"; `stale` (người khác vừa quyết định); `awaiting_second_approval` (chip "Chờ duyệt lần hai" ở đầu trang, ô quyết định khoá tới khi S23.15 xử lý xong); lỗi cổng khi hoàn sau commit: khoản hoàn sang S23.03 tab Thất bại, trang hiện "Đã quyết định; khoản hoàn đang chờ gửi lại" (plan S18 Decision 7, Ruling 7 của #129).
- **Chấp nhận:** support quyết định được, finance không thấy bằng chứng (DTO không có `evidencePaths`, `description`, tin nhắn); số tiền trên hộp xác nhận bằng số tiền ghi vào sổ; hoàn 12.000.000₫ cần người thứ hai; mỗi lần "Xem chat booking" có một dòng audit.

## 3. S23.06 · Hộp thư hỗ trợ

### 3.1 Bố cục `/staff/inbox`

- Hai cột: danh sách hội thoại (trái, 360 px) và hội thoại đang mở (phải).
- Bộ lọc trên danh sách: **Chờ trả lời** (`awaitingStaff`, mặc định) · **Của tôi** (`assigneeId = tôi`) · **Đang mở** · **Đã đóng**; loại: Trợ giúp / Khiếu nại (sales chỉ thấy Trợ giúp).
- Mỗi dòng: tên người dùng (trợ giúp) hoặc mã khiếu nại, xem trước tin cuối (≤ 80 ký tự), thời gian, chip "Chờ 5 giờ" (đỏ khi quá 12 giờ), avatar người đang xử lý.
- Hội thoại đang mở:
  - Đầu: tên + vai trò người dùng (khách / thợ / studio), link sang S23.04 (thợ) hoặc S23.01 (khiếu nại), nút "Nhận xử lý" / "Bỏ nhận", "Đóng hội thoại" (chỉ trợ giúp; khiếu nại đóng theo kết quả).
  - Thân: tin nhắn theo thời gian, tin của staff ký "Hỗ trợ" và (chỉ staff thấy) tên người gửi lấy từ `audit_log`.
  - Ô trả lời 1–1000 ký tự, Enter gửi, Shift+Enter xuống dòng; nút chính "Gửi".
  - Ngăn phải thu gọn được: 5 booking gần nhất của người dùng, khiếu nại đang mở, trạng thái xác minh; tab "Ghi chú nội bộ".

### 3.2 Làm mới và chi phí đọc

- Danh sách: 30 giây (spec dashboard §2.5).
- Hội thoại đang mở: 10 giây, chỉ lấy tin mới hơn tin cuối đã có (`createdAt > last`, `limit 50`), nên lần làm mới không có tin mới tính 1 lượt đọc.

### 3.3 Thao tác

| Thao tác | Callable | Quyền | Ghi chú |
|---|---|---|---|
| Trả lời | `staffReplySupport({threadId, messageId, body})` | `support.reply`; hội thoại khiếu nại cần thêm `support.view_dispute` | Tin `senderId: null`, `senderRole: staff`, `senderName: "Hỗ trợ"`; đặt `awaitingStaff = false`; mở lại hội thoại trợ giúp đã đóng; thông báo `support_reply` (#138); audit `support.reply`. `messageId` là ULID client tạo (chống gửi trùng). |
| Nhận / bỏ nhận | `assignSupportThread({threadId, assigneeId \| null})` | `support.assign` | Chỉ tự nhận hoặc bỏ nhận của mình; admin giao cho người khác được. |
| Đóng | `closeSupportThread({threadId, reason})` | `support.close` | Chỉ `kind = help`. Người dùng nhắn lại thì server mở lại. |
| Ghi chú nội bộ | `addStaffNote({threadId, body})` | `support.note` | `staff_notes/{ulid}` `{authorId, body, createdAt}`; client không đọc. |

## 4. Bảng quyền và thay đổi backend

**`StaffAction` thêm:**

| Action | admin | finance | support | sales |
|---|---|---|---|---|
| `dispute.view` (đầy đủ) | ✓ | — | ✓ | — |
| `dispute.view_summary` (số tiền, trạng thái, kết quả) | ✓ | ✓ | ✓ | — |
| `dispute.resolve`, `dispute.chat_view` | ✓ | — | ✓ | — |
| `support.view_help`, `support.reply`, `support.assign`, `support.close`, `support.note` | ✓ | — | ✓ | ✓ |
| `support.view_dispute` | ✓ | — | ✓ | — |

`APPROVAL_KINDS` thêm `dispute_resolve` (đề xuất và duyệt đều cần `dispute.resolve`; cần hai người khi `refundAmount ≥ twoPersonThreshold`).

**Thay đổi so với plan S18 (#142), làm trong plan #165 sau khi #142 merge:**
- `resolveDispute`: `assertStaff(request, 'dispute.resolve')` thay cho `staffRole == 'admin'`; ghi `audit_log` (`dispute.resolve`, `diff` có outcome); đi qua `staff_approvals` khi đủ ngưỡng.
- `support_threads`: thêm `assigneeId: string | null` (server-only, rules không trả cho người dùng: tách sang `support_threads_staff/{threadId}` nếu rules không lọc được trường; plan quyết), subcollection `staff_notes`.
- Tin staff: `senderId: null` (K4). CLI `npm run support -- reply` đổi theo.
- `getSensitiveFileUrl` `kind: dispute_evidence`: đường dẫn thật của plan S18 là `disputeEvidence/{uid}/{disputeId}/{fileId}`; callable nhận `{entityId: disputeId, file}` và chỉ ký khi đường dẫn nằm trong `disputes/{id}.evidencePaths` (sửa bảng `kind` ở spec dashboard §5.2).
- Mới: `getBookingChatForDispute({disputeId, before?})` → 50 tin nhắn chat booking trước mốc `before` (chỉ khi khiếu nại `open` hoặc mới có kết quả trong 7 ngày), ghi `audit_log` `dispute.chat_view`.

**Đọc (lớp đọc BFF):** `disputes` theo `(status, createdAt)`; `support_threads` theo `(status, awaitingStaff, lastMessageAt)` và `(assigneeId, lastMessageAt)`; tin nhắn theo `(createdAt)`. Index thêm vào `firestore.indexes.json`. DTO cho finance bỏ `description`, `evidencePaths`, `threadId`.

## 5. Chi phí

- Khiếu nại: vài cái mỗi tuần; trang chi tiết đọc khoảng 10 doc (dispute, booking, payment, milestones, hai hồ sơ, 50 tin nhắn lần đầu). Không đáng kể.
- Hộp thư: 3 staff × 8 giờ × 360 lần làm mới/giờ (10 giây) ≈ 8.600 lượt đọc/ngày khi luôn mở một hội thoại, cộng danh sách 30 giây (≈ 2.900 × số dòng thay đổi). Dưới hạn mức 50.000/ngày; nếu vượt, hạ hội thoại xuống 20 giây.
- Callable trả lời: vài trăm lần/tháng. Cộng thêm **~$0** ở cả hai mức người dùng.

## 6. Kiểm thử

- **Domain:** `resolveDispute` với `split` 1/99/50 trên mốc và trên payment không có mốc (đúng làm tròn xuống); ngưỡng hai người theo `refundAmount` (9.999.999 / 10.000.000); `dispute_resolve` qua `staff_approvals` (người đề xuất không tự duyệt; finance không duyệt được).
- **Functions:** `staffReplySupport` không ghi uid staff vào tin nhắn; sales trả lời hội thoại khiếu nại bị từ chối; `getBookingChatForDispute` từ chối khi khiếu nại đã đóng quá 7 ngày và ghi audit khi được; `getSensitiveFileUrl` từ chối đường dẫn không nằm trong `evidencePaths`.
- **Rules:** người dùng không đọc `staff_notes`, không thấy `assigneeId`.
- **Dashboard:** DTO của finance không có lời kể, bằng chứng, tin nhắn; số tiền tính sẵn ở ô "Chia" khớp `floor`; danh sách hộp thư của sales chỉ có loại Trợ giúp.
- **Playwright:** support mở khiếu nại seed `seed-dispute-lan-an`, chia 30%, xác nhận → `disputes` `resolved`, hai bên nhận thông báo, có khoản hoàn và một dòng audit; support trả lời một hội thoại trợ giúp → người dùng thấy tin ký "Hỗ trợ".

## 7. Phụ thuộc

- Cứng: #162 (nền tảng, `staff_approvals`), #142 (S18: `disputes`, `support_threads`, `resolveDispute`).
- Mềm: #207 (huỷ phần bàn giao) chỉ đổi nghĩa cờ "Giao trễ hạn"; #152 (mốc tiền) để hiện bảng mốc, trước đó là một dòng "toàn bộ".

## 8. Câu hỏi mở (có mặc định)

| # | Câu hỏi | Mặc định |
|---|---|---|
| Q1 | Hạn xử lý khiếu nại? | 72 giờ từ lúc mở |
| Q2 | Hạn trả lời hội thoại? | 12 giờ khi `awaitingStaff` |
| Q3 | Mẫu câu trả lời soạn sẵn? | Chưa làm |
| Q4 | Người dùng thấy tên staff không? | Không, luôn ký "Hỗ trợ" |
