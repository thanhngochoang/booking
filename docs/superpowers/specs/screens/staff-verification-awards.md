# S23 · Duyệt xác minh & giải thưởng (#164)

- **Issue:** #164, epic #83. **Ngày:** 2026-10-08. **Trạng thái:** chờ chủ dự án duyệt.
- **Dựa trên:** `../2026-10-08-dashboard-web-design.md` ("spec dashboard": quyền, `audit_log`, `getSensitiveFileUrl`, `staff_approvals` §5.4, mẫu hàng đợi), `../2026-10-06-identity-verification-design.md` ("spec xác minh"), plan `../../plans/2026-10-07-s21-verification.md` (#135, chưa merge), `../2026-10-05-provider-types-portfolio-jobs-design.md` §2 (giải thưởng, hạng NAG), plan `../../plans/2026-10-07-s25-awards.md` (#145, đã merge).
- **Mock:** `docs/design/dashboard-mock.html#S23.04`, `#S23.07`.
- **Vai trò:** `admin`, `support` (spec dashboard §4.2). Finance và sales không thấy các màn này.

## 0. Quyết định

| # | Quyết định | Nguồn |
|---|---|---|
| V1 | **Hạng NAG chờ xác minh.** Giải thưởng vẫn được duyệt và đếm như cũ, nhưng `providerType` chỉ lên `artist` khi đủ 3 giải đã duyệt **và** `photographers/{uid}.verified == true`. Thợ chưa xác minh đủ 3 giải thì ở trạng thái "đủ điều kiện, chờ xác minh"; khi S21 được duyệt (hoặc khôi phục) thì hạng tự cấp. Thu hồi xác minh thì mất hạng NAG (giải vẫn giữ). Staff không tự xác minh danh tính ở S23.07. Thay câu "S23.07 yêu cầu staff xác minh danh tính cùng lúc" của spec 10-05 §2.3. | chủ dự án 2026-10-08 |
| V2 | **Khôi phục xác minh đã thu hồi:** chỉ admin đề xuất, kèm lý do; một staff khác (admin hoặc support) xác nhận qua `staff_approvals` (`kind: verification_reinstate`). Thợ về `approved`, không trả phí lại. Thay mặc định "thu hồi là vĩnh viễn" của plan S21 (Needs the owner 3, Decision 14). | chủ dự án 2026-10-08 |
| V3 | Staff thấy họ tên, ngày sinh, **4 số cuối** số định danh, kết quả kiểm tra tự động và cảnh báo trùng (spec xác minh §4). Dữ liệu danh tính không qua lớp đọc của BFF mà qua callable `getVerificationForReview`, để mỗi lần mở được ghi `audit_log` (`verification.view`). | spec dashboard D2, V3 ở đây |
| V4 | Không bao giờ tự duyệt. Xác minh quá 24 giờ, giải thưởng quá 3 ngày làm việc thì hàng đợi đỏ. | spec xác minh §4, spec 10-05 §2 |

## 1. Màn và mã

| Mã | Màn | Route |
|---|---|---|
| S23.04 | Duyệt xác minh: danh tính, doanh nghiệp, thu hồi, khôi phục | `/staff/verifications` |
| S23.07 | Duyệt giải thưởng | `/staff/awards` |

Thanh bên nhóm "Hàng đợi": Xác minh · Giải thưởng. Thẻ trên S23.09: xác minh danh tính chờ duyệt, doanh nghiệp chờ duyệt, giải thưởng chờ duyệt. Ô "Tìm theo mã" nhận uid của thợ và mở thẳng S23.04 chi tiết của người đó.

## 2. S23.04 · Duyệt xác minh

- **Thông tin:** `/staff/verifications` · admin, support · chưa có. Cần #135.
- **Mục đích:** cho thợ thật vào nhận đơn trong 24 giờ, chặn tài khoản giả.
- **Điểm vào → ra:** S23.09, thanh bên, ô tìm theo mã → quyết định xong thì sang dòng kế tiếp trong hàng đợi.
- **Bố cục:** tab **Danh tính** (`status = submitted`) · **Doanh nghiệp** (`business.status = submitted`) · **Đã duyệt** (tìm theo tên hoặc uid; để thu hồi) · **Đã thu hồi** · **Lịch sử** (quyết định trong 30 ngày).

### 2.1 Tab Danh tính

- Bảng: thợ (tên hiển thị, loại `individual` / `artist` / `studio`, khu vực), gửi lúc, lần gửi (1, 2… tính cả lần gửi lại), cờ (chip đỏ "Trùng tài khoản" khi có cảnh báo trùng; "Quá 24 giờ").
- `DetailPane` (dữ liệu từ `getVerificationForReview`):
  - **Danh tính:** họ tên trên giấy tờ, ngày sinh (và tuổi), giới tính, số định danh •••• 4 số cuối, cách xác minh (VNeID / chip CCCD), kết quả kiểm tra tự động (đạt / không đạt).
  - **Cảnh báo:** trùng `idHash` với tài khoản khác (link sang S23.04 của tài khoản đó, trạng thái của nó); tên hiển thị khác xa họ tên trên giấy tờ (chỉ để lưu ý).
  - **Hồ sơ công khai:** ảnh đại diện, 6 ảnh portfolio mới nhất (ảnh công khai, không cần URL ký), tên hiển thị, khu vực, giới thiệu, ngày tạo tài khoản.
  - **Các bước:** điện thoại đã xác minh, phí đã trả (mã thanh toán), quy định đã đồng ý (phiên bản).
  - **Lịch sử:** các lần từ chối trước (lý do, ghi chú, người quyết định), `freeResubmitsLeft`.
- Chân: chính **"Duyệt"**; phụ **"Từ chối…"**.
- "Duyệt" → `DecisionDialog` "Cho {tên} nhận đơn?" + lý do (5–500 ký tự) → `reviewVerification({uid, target: 'identity', action: 'approve', note})`. Thông báo cho thợ do #135 gửi. Nếu thợ đủ 3 giải đã duyệt thì hộp ghi thêm "Hạng NAG sẽ được cấp cùng lúc" (V1).
- "Từ chối…" → hộp có nhóm lý do: Ảnh đại diện giả (`fake_avatar`), Portfolio lấy của người khác (`stolen_portfolio`), Không khớp danh tính (`identity_mismatch`), Trùng tài khoản (`duplicate_account`), Chưa đủ 18 tuổi (`underage`), Khác (`other`, bắt ghi chú). Dòng phụ nói rõ hậu quả: hai lý do `duplicate_account`, `underage` là **từ chối hẳn**, không gửi lại được; các lý do khác còn {n} lần gửi lại miễn phí. Nút đỏ "Từ chối".

### 2.2 Tab Doanh nghiệp

- Bảng: studio, mã số thuế, tên doanh nghiệp tra được, gửi lúc.
- `DetailPane`: mã số thuế, tên, địa chỉ, tình trạng (tra cứu), loại (công ty; hộ kinh doanh tự duyệt nên không vào đây), ảnh giấy đăng ký (`SecureFileViewer`, `kind: business_doc`), **họ tên đã xác minh của chủ studio** để so với người đại diện trên giấy.
- Chân: chính "Duyệt"; phụ "Từ chối…" với lý do Ngừng hoạt động (`inactive`), Người đại diện không khớp (`representative_mismatch`), Ảnh không đọc được (`doc_unreadable`), Khác (`other`). → `reviewVerification({uid, target: 'business', …})`.

### 2.3 Tab Đã duyệt: thu hồi

- Bảng tìm theo tên hoặc uid: thợ, ngày duyệt, người duyệt, số booking đang chạy.
- "Thu hồi xác minh…" (nút đỏ trong hộp, lý do bắt buộc ít nhất 20 ký tự) → `reviewVerification({uid, target: 'identity', action: 'revoke', note})`: tắt nhận đơn, ẩn dấu tích, mất hạng NAG (V1). Hộp nói rõ: "{n} booking đang chạy không bị huỷ; xử lý qua khiếu nại nếu cần" (spec xác minh §4).

### 2.4 Tab Đã thu hồi: khôi phục

- Bảng: thợ, ngày thu hồi, người thu hồi, lý do.
- Admin thấy "Khôi phục…" → lý do → `reinstateVerification({uid, reason})` → luôn tạo yêu cầu `staff_approvals` (`verification_reinstate`), trạng thái dòng thành "Chờ duyệt lần hai". Support thấy dòng nhưng không có nút đề xuất.
- Người thứ hai duyệt ở S23.15 → `revoked → approved` trong một transaction với `photographers/{uid}` `{verified: true, acceptingOrders: acceptsOrders(…)}` và tính lại hạng NAG (V1).

### 2.5 Dữ liệu, quá hạn, trạng thái

- **Đọc:** danh sách từ `verifications` theo `(status, submittedAt)` và `(business.status, business.submittedAt)`, trang 50; chi tiết qua `getVerificationForReview({uid})` (callable, quyền `verification.view`, ghi `audit_log` `verification.view`; trả DTO chỉ có 4 số cuối). Hồ sơ công khai và portfolio đọc thẳng bằng lớp đọc.
- **Quá hạn:** danh tính và doanh nghiệp quá 24 giờ (`REVIEW_SLA_HOURS` của #135).
- **Trạng thái:** trống "Không có hồ sơ nào chờ duyệt"; `stale` khi người khác vừa quyết định ("Hồ sơ này vừa được {tên} xử lý"); thợ đã rút về `in_progress` (sửa và gửi lại) thì dòng biến mất ở lần làm mới.
- **Chấp nhận:** support duyệt được; finance và sales nhận 403; mỗi lần mở chi tiết có một dòng `verification.view`; không có màn nào hiện quá 4 số cuối của số định danh; thợ duyệt xong nhận đơn được ngay (S02.06 hiện thợ).

## 3. S23.07 · Duyệt giải thưởng

- **Thông tin:** `/staff/awards` · admin, support · chưa có. `reviewAward` đã có (#145); đổi quyền và thêm audit (§4).
- **Mục đích:** chỉ giải có thật mới hiện trên hồ sơ và tính vào hạng NAG; duyệt trong 3 ngày làm việc như S25.02 hứa.
- **Bố cục:** tab **Chờ duyệt** (`pending`) · **Cần bổ sung** (`needs_info`, đang chờ thợ; chỉ xem, có tuổi) · **Đã duyệt** (để thu hồi) · **Đã từ chối**.
  - Bảng: thợ, cuộc thi, năm, kết quả (Vàng, Bạc, Đồng, Khuyến khích, Chung khảo, Triển lãm), gửi lúc, chờ bao lâu ("2 ngày làm việc"; đỏ khi quá 3).
  - `DetailPane`:
    - Thông tin giải: cuộc thi, năm, hạng mục, kết quả, bài dự thi (ảnh công khai nếu có `workPostId`).
    - **Minh chứng:** tối đa 3 tệp (`SecureFileViewer`, `kind: award_proof`) và 2 link. Link mở tab mới với `rel="noopener noreferrer"`, hiện tên miền trước khi mở.
    - **Tiến độ NAG:** "{n}/3 giải đã duyệt" và trạng thái xác minh. Khi duyệt giải này làm đủ 3: đã xác minh thì banner "Duyệt giải này sẽ cấp hạng NAG"; chưa xác minh thì "Đủ điều kiện NAG, chờ xác minh danh tính" (V1). Thợ là studio thì không có dòng này.
    - Lịch sử của giải: các lần cần bổ sung, ghi chú staff, phản hồi của thợ.
  - Chân (tab Chờ duyệt): chính **"Duyệt"**; phụ **"Cần bổ sung…"** (ghi chú bắt buộc, gửi cho thợ), **"Từ chối…"** (đỏ trong hộp, ghi chú bắt buộc). Tab Đã duyệt: "Thu hồi…" (đỏ trong hộp, ghi chú bắt buộc).
- **Tương tác:** mọi nút gọi `reviewAward({awardId, action, note})`; `note` 5–500 ký tự, bắt buộc trừ khi duyệt (hộp duyệt vẫn có ô lý do tuỳ chọn; spec dashboard yêu cầu lý do cho thao tác đổi trạng thái, ở đây duyệt giải là ngoại lệ có chủ ý theo spec 10-05: "lý do bắt buộc trừ khi duyệt").
- **Dữ liệu:** `awards` theo `(status, createdAt)`; số giải đã duyệt của thợ bằng `count()`; `photographers/{uid}.verified`.
- **Quá hạn:** `pending` quá 3 ngày làm việc (thứ Hai–thứ Sáu, giờ Việt Nam; chưa tính ngày lễ).
- **Chấp nhận:** duyệt giải thứ 3 của thợ đã xác minh làm `providerType = artist` ngay; của thợ chưa xác minh thì không đổi, và khi S21 được duyệt thì đổi; thu hồi giải làm tụt dưới 3 thì mất hạng (như #145); `CLI awards` vẫn chạy.

## 4. Thay đổi backend

**Domain (`packages/domain`):**
- `tierFor(current, approvedCount, verified)`: `artist` khi `current ≠ studio`, `approvedCount ≥ ARTIST_THRESHOLD` và `verified`. Mọi chỗ gọi (`reviewAward`, đổi loại nhà cung cấp) truyền `verified`.
- Use case xác minh của #135 (`reviewVerification` approve/revoke) gọi tính lại hạng trong cùng transaction: approve có thể cấp `artist`, revoke đưa `artist` về `individual` (giải giữ nguyên). Thông báo `artist_granted` (đã có) gửi khi cấp.
- `reinstateVerification`: chuyển `revoked → approved` (chuyển mới trong máy trạng thái của #135), đặt lại cờ công khai như approve, tính lại hạng. Chỉ chạy qua `staff_approvals`.
- `StaffAction` thêm: `verification.view`, `verification.review`, `verification.revoke` (admin, support); `verification.reinstate.request` (admin); `verification.reinstate.decide` (admin, support); `award.view`, `award.review` (admin, support). `APPROVAL_KINDS` thêm `verification_reinstate` (đề xuất `verification.reinstate.request`, duyệt `verification.reinstate.decide`).

**Functions:**
- `reviewAward`: thay kiểm `staffRole === 'admin'` bằng `assertStaff(request, 'award.review')`; ghi thêm `audit_log` (`award.approve`, `award.needs_info`, `award.reject`, `award.revoke`) cạnh `awardAudit`.
- `reviewVerification` (#135): `assertStaff` với `verification.review` / `verification.revoke`; ghi `audit_log` cạnh `verificationAudit`.
- Mới: `getVerificationForReview({uid})` → DTO `{verification, identity: {legalName, dob, gender, idLast4, method, passed}, duplicates: [{uid, status}], business?: {taxCode, name, address, registryStatus, docFiles: [tên tệp]}, history}`; `reinstateVerification({uid, reason})`.
- CLI `verifications` và `awards` giữ nguyên, đi qua cùng use case.

**App (nhỏ, cùng plan):** S25.01 thêm trạng thái "Đủ 3 giải · xác minh danh tính để lên Nhiếp ảnh gia" (mở `/verify/start`) khi đủ giải mà chưa xác minh; câu chữ thêm vào `app_vi.arb` và mock điện thoại `#S25.01`.

**Spec khác cần sửa cùng plan:** spec 10-05 §2.3 (V1), spec xác minh §4 (khôi phục, V2), `data-model/domain-model.md` (chuyển `revoked → approved`).

## 5. Chi phí

Mỗi lần mở chi tiết xác minh: 1 lần gọi callable + khoảng 6 lượt đọc (verification, identity, `identity_hashes`, photographer, 1 truy vấn portfolio, lịch sử audit) + 1 ghi audit. Vài chục hồ sơ mỗi ngày → vài trăm lượt đọc/ngày, trong hạn mức. URL ký cho giấy tờ và minh chứng: không tốn thêm ngoài băng thông Storage (ảnh ≤ 2 MB, vài chục lần/ngày, < 1 GB/tháng). Cộng thêm **~$0** ở cả hai mức người dùng.

## 6. Kiểm thử

- **Domain:** `tierFor` (bảng: studio, chưa xác minh + 3 giải, đã xác minh + 2 giải, đã xác minh + 3 giải); approve xác minh của thợ có 3 giải → `artist`; revoke → `individual`; `reinstateVerification` chỉ từ `revoked`, chạy qua `staff_approvals` (người đề xuất không tự duyệt, support duyệt được, finance không).
- **Functions:** `reviewAward` với support (được), finance (403), thiếu TOTP (`mfa_required`); `getVerificationForReview` trả `idLast4` chứ không phải số đầy đủ, ghi `verification.view`; `reinstateVerification` bởi support bị từ chối đề xuất.
- **Dashboard:** hộp từ chối hiện "từ chối hẳn" cho `duplicate_account` và `underage`; banner NAG đúng ba trường hợp; link minh chứng có `rel="noopener noreferrer"`.
- **Playwright:** support duyệt một hồ sơ danh tính seed → thợ có `verified = true`; admin đề xuất khôi phục, admin khác duyệt ở S23.15 → `approved`.

## 7. Phụ thuộc

- Cứng: #162 (nền tảng, `staff_approvals`), #135 (S21). S23.07 làm được ngay sau #162 vì #145 đã merge.
- Plan có thể chia hai phần: S23.07 trước (không chờ #135), S23.04 sau khi #135 merge.

## 8. Câu hỏi mở (có mặc định)

| # | Câu hỏi | Mặc định |
|---|---|---|
| Q1 | Ngày lễ có tính vào "3 ngày làm việc"? | Chưa tính; thêm bảng ngày lễ khi cần |
| Q2 | Cảnh báo "tên hiển thị khác họ tên trên giấy tờ" dùng ngưỡng nào? | Không so tự động; chỉ hiện hai tên cạnh nhau |
| Q3 | Thợ bị thu hồi rồi khôi phục có được thêm một lần gửi lại miễn phí? | Không đổi `freeResubmitsLeft` |
