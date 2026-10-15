# S23 · Kiểm duyệt (#166)

- **Issue:** #166, epic #83. **Ngày:** 2026-10-08. **Trạng thái:** chờ chủ dự án duyệt.
- **Dựa trên:** `../2026-10-08-dashboard-web-design.md` ("spec dashboard": quyền, `audit_log`, `staff_approvals` §5.4, mẫu hàng đợi), spec chính §3i.3 (S20), plan `../../plans/2026-10-07-s20-report-block.md` (#144, chưa merge; "plan S20"), plan `../../plans/2026-10-07-s27-studio-recruiting.md` (#151, chưa merge; "plan S27"), plan `../../plans/2026-10-07-s15-s16-job-posts.md` (#139).
- **Mock:** `docs/design/dashboard-mock.html#S23.05`, `#S23.16`, `#S23.17`.
- **Vai trò:** `admin`, `support`. Khoá hẳn chỉ `admin` đề xuất.

## 0. Quyết định

| # | Quyết định | Nguồn |
|---|---|---|
| D1 | Hai mức khoá tài khoản: **khoá tạm** 7 hoặc 30 ngày (admin, support) và **khoá hẳn** (chỉ admin đề xuất). Khoá hẳn tài khoản thợ đang có booking chưa xong hoặc tiền đang giữ cần người thứ hai (`staff_approvals`, `kind: account_ban`, người duyệt admin hoặc support). Admin mở khoá được. Thay "takedown user = disable vĩnh viễn" của plan S20 Decision 10. | chủ dự án 2026-10-08 |
| D2 | **Không tự ẩn** nội dung theo số báo cáo. Báo cáo được gộp theo nội dung; nội dung có từ 3 người báo cáo khác nhau, hoặc có lý do `scam`, đứng đầu hàng đợi và tô đỏ. | chủ dự án 2026-10-08 |
| D3 | Khoá (tạm hoặc hẳn) thì: Auth `disabled` + thu hồi token; với thợ, `photographers/{uid}.suspended = true` để cổng nhận đơn (`ProviderOrderGate`) từ chối và Tìm thợ không hiện. Booking đang chạy **không** tự huỷ; màn liệt kê chúng để hỗ trợ liên hệ khách. | luật tiền: không tự di chuyển tiền |
| D4 | Khoá tạm không đụng chi trả (tiền của việc đã làm). Khoá hẳn tạm giữ mọi khoản chi đang mở (`holdReason: 'account_banned'`); finance quyết ở S23.02 sau khi xem xét. | luật tiền, #163 |
| D5 | Staff xem được **5 tin trước và 5 tin sau** một tin nhắn bị báo cáo (người báo cáo là thành viên cuộc trò chuyện), mỗi lần xem ghi `audit_log` (`report.context_view`). | cần ngữ cảnh để phân xử quấy rối |
| D6 | Báo cáo mở rộng cho **việc đăng** (`job`, S15) và **tin tuyển** (`recruit_post`, S27). Gỡ = đóng tin bằng use case đóng có sẵn của #139 / #151 với lý do `staff_removed`. Điểm vào "Báo cáo" trên các màn đó do plan #166 thêm sau khi #139 / #151 merge. | các plan đó để staff tools cho #83 |

## 1. Màn và mã

| Mã | Màn | Route |
|---|---|---|
| S23.05 | Kiểm duyệt báo cáo (người dùng, bài, tin nhắn, sự kiện, việc đăng, tin tuyển) | `/staff/reports` |
| S23.16 | Tài khoản bị khoá: khoá, mở khoá, gia hạn | `/staff/suspensions` |
| S23.17 | Cờ tuyển thợ: chưa trả công, lôi kéo thợ | `/staff/recruit-flags` |

Thanh bên: nhóm "Hàng đợi" thêm Báo cáo · Cờ tuyển thợ; nhóm "Hệ thống" thêm Tài khoản bị khoá. Thẻ S23.09: báo cáo đang mở (đỏ khi có nội dung ưu tiên quá 24 giờ), cờ tuyển thợ mới.

## 2. S23.05 · Kiểm duyệt báo cáo

### 2.1 Gộp theo nội dung

Trigger mới `onReportCreated` (không đổi `submitReport` của plan S20) cập nhật `report_targets/{targetType}_{targetKey}`:

```
report_targets/{id}
  targetType     user | post | message | event | job | recruit_post
  targetKey, targetId, chatId?, ownerId?
  snapshot       bản chụp của báo cáo đầu tiên {name, excerpt, imageUrl}
  reporterCount  số người báo cáo khác nhau
  reasons        {scam: 2, harassment: 1, …}
  priority       true khi reporterCount ≥ 3 hoặc có scam
  status         open | dismissed | actioned
  firstAt, lastAt, decidedBy?, decidedAt?, staffNote?, action?
```

Quyết định trên một `report_targets` đóng mọi báo cáo `open` của nó (`reports.status`, `staffNote`, `decidedBy`, `decidedAt` như plan S20). Báo cáo mới tới sau khi đã quyết thì mở lại `report_targets` (`status = open`), giữ lịch sử quyết định cũ.

### 2.2 Bố cục

- Tab **Đang mở** · **Đã xử lý** (30 ngày); lọc theo loại nội dung.
- Bảng: loại (icon + nhãn), nội dung (tên hoặc trích ≤ 80 ký tự), chủ nội dung, số người báo cáo, lý do chính (chip; `scam` đỏ), báo cáo đầu lúc. Sắp: ưu tiên quá hạn, ưu tiên, rồi cũ nhất.
- `DetailPane`:
  - **Nội dung:** bản chụp lúc báo cáo cạnh **nội dung hiện tại** (đã xoá thì ghi "Đã bị xoá bởi chủ"). Ảnh của bài là ảnh công khai. Tin nhắn: nút "Xem ngữ cảnh" (D5).
  - **Chủ nội dung:** tên, vai trò, tuổi tài khoản, đã xác minh chưa, số lần bị xử lý trước, trạng thái khoá; link S23.04 (thợ) và S23.16.
  - **Các báo cáo:** mỗi dòng người báo cáo (tên, tuổi tài khoản), lý do, ghi chú, lúc. Tài khoản báo cáo tạo dưới 7 ngày có chip "Tài khoản mới" (dấu hiệu báo cáo hàng loạt).
  - Chân: chính **"Gỡ nội dung…"** (người dùng: **"Khoá tài khoản…"**); phụ **"Bỏ qua…"**.
- **Gỡ nội dung…** → hộp: hậu quả theo loại (bài: xoá bài và ẩn khỏi timeline sự kiện; tin nhắn: thay bằng "Tin nhắn đã bị gỡ"; việc đăng / tin tuyển: đóng tin, báo giá hoặc đơn ứng tuyển đang mở được đóng theo luật của tin; sự kiện: không gỡ ở đây, link "Huỷ sự kiện" sang màn quản lý sự kiện của #168), ô đánh dấu "Khoá luôn chủ nội dung" mở thêm lựa chọn 7 ngày / 30 ngày / khoá hẳn (khoá hẳn chỉ admin), ghi chú 5–500 ký tự, nút đỏ "Gỡ".
- **Bỏ qua…** → ghi chú → `dismiss`.
- **Quá hạn:** nội dung ưu tiên quá 24 giờ, còn lại quá 72 giờ.

### 2.3 Chấp nhận

Ba người báo cáo cùng một bài cho ra một dòng có số 3 và tô đỏ; gỡ bài đóng cả ba báo cáo; người báo cáo không nhận tên staff; mỗi lần xem ngữ cảnh tin nhắn có một dòng audit; báo cáo sự kiện không có nút gỡ.

## 3. S23.16 · Tài khoản bị khoá

```
moderation/{uid}                      (server-only)
  status       active | suspended | banned
  until        thời điểm hết khoá tạm, null khi khoá hẳn
  reason       mã: harassment | scam | spam | inappropriate | stolen_photos | impersonation | fake_account | other
  note, by, at
  history[]    các lần khoá / mở trước
```

- **Bố cục:** tab **Đang khoá** · **Lịch sử**. Bảng: người dùng, vai trò, mức (Tạm 7 ngày / Tạm 30 ngày / Khoá hẳn), tới lúc, lý do, người khoá. `DetailPane`: lịch sử khoá, báo cáo liên quan, **booking chưa xong** (vai trò khách hoặc thợ, link), **tiền đang giữ và khoản chi đang mở** (chỉ số tiền). Nút chính "Khoá tài khoản…" ở đầu trang (tìm theo email hoặc uid bằng `findUserForStaff`). Trong chi tiết: "Gia hạn…", "Chuyển thành khoá hẳn…" (admin), "Mở khoá…" (admin).
- **Khoá** → hộp: mức, lý do, ghi chú; hộp nêu số booking chưa xong và số tiền đang giữ. Khoá hẳn thợ có booking chưa xong hoặc tiền đang giữ → "Gửi duyệt lần hai".
- **Hết hạn khoá tạm:** bước mới `liftExpiredSuspensions` trong job hằng ngày đang có (theo luật bước của job định kỳ, bảng đối chiếu S04): bật lại Auth, `suspended = false`, ghi `history`, audit với actor `system`.
- **App (nhỏ, cùng plan):** đăng nhập gặp `auth/user-disabled` thì S01.03 hiện "Tài khoản đang bị khoá. Liên hệ hỗ trợ: {SUPPORT_EMAIL}" (ẩn email khi chưa cấu hình); S03.01 của thợ `suspended` hiện như "Chưa nhận đơn".
- **Chấp nhận:** thợ bị khoá tạm không xuất hiện ở Tìm thợ và không nhận được booking mới (`not_accepting_orders`); hết hạn thì tự mở; khoá hẳn tạm giữ khoản chi đang mở với lý do `account_banned`; khoá tạm thì không.

## 4. S23.17 · Cờ tuyển thợ

Plan S27: job cộng tác còn `due` 7 ngày sau hạn, hoặc `disputed`, thêm một cờ vào `unpaidFlags` của studio; 3 cờ trong 90 ngày đặt `recruitBlockedUntil = now + 30 ngày`; cờ không tự xoá; tín hiệu lôi kéo thợ ghi `staff_flags/poach_{photographerId}_{customerId}`, chỉ để staff xem.

- **Tab Chưa trả công:** studio có cờ trong 90 ngày. Bảng: studio, số cờ, khoá đăng tin tới, cờ mới nhất. `DetailPane`: từng cờ (job cộng tác, cộng tác viên, thù lao, lý do `overdue` / `disputed`, ngày), trạng thái trả công của job (`due`, `paid_reported`, `disputed`), link hội thoại cộng tác (chỉ đọc, ghi audit như D5). Thao tác: **"Gỡ khoá đăng tin…"** (xoá `recruitBlockedUntil`, giữ cờ) và **"Xoá cờ…"** (cờ sai, ví dụ hai bên đã xác nhận đã trả), cả hai bắt ghi chú.
- **Tab Lôi kéo thợ:** `staff_flags` `kind = collab_poaching` chưa xử lý. Bảng: thợ, khách, studio, số booking riêng kể từ job cộng tác, ngày. `DetailPane`: các job cộng tác và booking riêng (ngày, giá). Thao tác: "Đánh dấu đã xem…" (ghi chú). Không có hình phạt tự động; staff muốn xử lý thì dùng S23.16.
- **Chấp nhận:** gỡ khoá đăng tin cho studio đăng tin ngay; xoá một cờ làm giảm số cờ trong 90 ngày nhưng không tự gỡ khoá đang có.

## 5. Bảng quyền và backend

**`StaffAction` thêm:** `report.view`, `report.decide`, `report.context_view`, `account.suspend`, `recruit_flag.view`, `recruit_flag.decide` (admin, support); `account.ban`, `account.unsuspend` (admin); `account.ban.decide` (admin, support). `APPROVAL_KINDS` thêm `account_ban` (cần hai người khi chủ tài khoản là thợ có booking chưa xong hoặc tiền đang giữ).

| Callable | Đầu vào | Làm gì |
|---|---|---|
| `decideReportTarget` | `{targetId, action: 'dismiss' \| 'takedown', suspend?: {level: 'd7' \| 'd30' \| 'ban', reason}, note}` | Đóng mọi báo cáo mở của nội dung; `takedown` theo loại (plan S20 Decision 10 cho bài, tin nhắn; đóng tin cho `job`, `recruit_post`; từ chối `event`); `suspend` gọi cùng use case với `suspendAccount` / `banAccount`. |
| `getReportContext` | `{targetId}` | Tin nhắn: 5 trước, 5 sau; audit `report.context_view`. |
| `suspendAccount` | `{uid, days: 7 \| 30, reason, note}` | D3; audit. Đang khoá thì gia hạn tới mốc mới. |
| `banAccount` | `{uid, reason, note}` | D3, D4; qua `staff_approvals` khi cần. |
| `liftSuspension` | `{uid, note}` | Bật lại Auth, `suspended = false`; không tự tiếp tục khoản chi đang giữ. |
| `liftRecruitBlock` | `{studioId, note}` | Xoá `recruitBlockedUntil`. |
| `removeUnpaidFlag` | `{studioId, flagId, note}` | Xoá một cờ khỏi `unpaidFlags`. |
| `reviewStaffFlag` | `{flagId, note}` | `staff_flags` thêm `reviewedBy`, `reviewedAt`, `note`. |

**Thay đổi so với plan khác (làm trong plan #166, sau khi các issue đó merge):**
- Plan S20: takedown `user` thay bằng khoá tạm / khoá hẳn; CLI `reports` thêm `suspend`, `ban`; `targetType` thêm `job`, `recruit_post`; trigger `onReportCreated`.
- `ProviderOrderGate` (`acceptsOrders`): thêm điều kiện `suspended != true`; Tìm thợ lọc `suspended`. `photographers.suspended` thuộc danh sách trường chỉ server ghi.
- Plan S27: `unpaidFlags` cần `id` cho từng cờ (để xoá một cờ); `staff_flags` thêm trường xem xét.
- Rules: client không đọc `report_targets`, `moderation`.
- Index: `report_targets (status, priority, firstAt)`, `moderation (status, until)`, `staff_flags (kind, reviewedAt, createdAt)`.

## 6. Chi phí

Trigger `onReportCreated`: một lần đọc + một lần ghi cho mỗi báo cáo (tối đa 20 báo cáo/người/ngày theo plan S20). Bước gỡ khoá hằng ngày: một truy vấn. Màn: vài chục dòng mở. Cộng thêm **~$0** ở cả hai mức người dùng.

## 7. Kiểm thử

- **Domain:** gộp báo cáo (ba người khác nhau → `reporterCount` 3, `priority`; một người báo hai lần không tăng); quyết định đóng mọi báo cáo mở; báo cáo sau khi quyết mở lại; `acceptsOrders` false khi `suspended`; khoá hẳn thợ có tiền giữ đi qua `staff_approvals`, khoá tạm thì không; `liftExpiredSuspensions` chỉ mở khoá đã hết hạn.
- **Functions:** support không khoá hẳn được; finance, sales bị từ chối mọi thao tác; `banAccount` giữ khoản chi `pending`/`needs_approval` với `account_banned`; `getReportContext` chỉ cho `message`.
- **Rules:** client không đọc `report_targets`, `moderation`, `staff_flags`.
- **App:** S01.03 với `auth/user-disabled` hiện câu khoá (có và không có `SUPPORT_EMAIL`).
- **Playwright:** support gỡ một bài bị ba người báo cáo và khoá chủ bài 7 ngày → bài mất khỏi feed, thợ không còn ở Tìm thợ, S23.16 có dòng hết hạn sau 7 ngày.

## 8. Phụ thuộc

- Cứng: #162, #144 (S20). S23.17 cần #151 (S27); báo cáo việc đăng cần #139.
- Plan có thể chia: S23.05 + S23.16 sau #144; S23.17 và các loại `job` / `recruit_post` sau #151 / #139.

## 9. Câu hỏi mở (có mặc định)

| # | Câu hỏi | Mặc định |
|---|---|---|
| Q1 | Bài của tài khoản bị khoá hẳn có tự ẩn khỏi feed? | Không; gỡ từng bài qua báo cáo. Hồ sơ thợ hiện như "Chưa nhận đơn" |
| Q2 | Người báo cáo có được báo kết quả? | Không gửi thông báo |
| Q3 | Tiền của thợ bị khoá hẳn sau khi xét xong | Finance quyết ở S23.02 (chi hoặc giữ chờ khiếu nại); chưa có luật tự động |
