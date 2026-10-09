# Dashboard web (Phase 1.5): kiến trúc, quyền và khung

- **Issue:** #161 (spec), áp dụng luôn cho #162 (nền tảng). Epic #83, milestone Phase 1.5.
- **Ngày:** 2026-10-08. **Trạng thái:** chờ chủ dự án duyệt.
- **Mock:** `docs/design/dashboard-mock.html` (màn S23.08–S23.11 và khung studio). Mở bằng trình duyệt, nút "Debug" hiện mã màn, thêm `#S23.09` vào URL để nhảy tới màn. Bản xuất bản: https://claude.ai/artifact/PG6UzagCjTxGfGUn9HRKJi (riêng tư; tệp trong repo là bản gốc để sửa).
- **Spec liên quan:** spec chính `2026-10-01-remaining-screens.md` (§2 bảng mã, §3i.6 S23), `data-model/README.md` (quy ước, ma trận quyền), `2026-10-06-payments-payouts-design.md`, `2026-10-06-identity-verification-design.md`, `2026-10-06-studio-members-design.md`.
- **Spec màn của từng ticket** (viết sau spec này, dùng chung mọi quy định ở đây):

  | Issue | Tệp |
  |---|---|
  | #163 S23 · Tiền | `screens/staff-money.md` |
  | #164 S23 · Xác minh & giải thưởng | `screens/staff-verification-awards.md` |
  | #165 S23 · Khiếu nại & hộp thư | `screens/staff-disputes-support.md` |
  | #166 S23 · Kiểm duyệt | `screens/staff-moderation.md` |
  | #167 S28 · Studio web: vận hành | `screens/studio-web-operations.md` |
  | #168 S23 · Cấu hình & nội dung | `screens/staff-config-content.md` |
  | #169 S28 · Studio web: kinh doanh | `screens/studio-web-business.md` |

## 0. Quyết định

| # | Quyết định | Nguồn |
|---|---|---|
| D1 | Dashboard là một ứng dụng Next.js (App Router, TypeScript strict) ở `apps/dashboard/`, dùng cho staff và chủ studio. Trả lời câu hỏi mở 22 của spec chính: web nội bộ riêng, không phải chế độ staff trong app. | #83, chủ dự án 2026-10-08 |
| D2 | **Trình duyệt không gọi Firestore hay Storage.** Mọi dữ liệu qua lớp server của Next.js (BFF). BFF **đọc** bằng Firebase Admin SDK qua các interface đọc, **ghi** bằng cách gọi callable của Cloud Functions với ID token của chính người dùng. BFF không tự ghi Firestore. | chủ dự án 2026-10-08 (hướng B) |
| D3 | **Phase 1.5 chạy local với emulator**, không deploy. Chủ dự án tắt mọi thứ cần gói Blaze (2026-10-09, công tắc `BLAZE_ENABLED` trong `firebase-deploy.yml`, `docs/FIREBASE-SETUP.md` §10). Khi bật Blaze: deploy lên **Firebase App Hosting**, region `asia-southeast1`, cùng project với Functions (§9). Phase 2 chuyển sang VPS cùng Go (#92, #98). | chủ dự án 2026-10-08, 2026-10-09 |
| D4 | Vai trò staff: `admin`, `finance`, `support`, `sales` (claim `staffRole`, mỗi người một vai trò). Trả lời câu hỏi mở 18. | chủ dự án 2026-10-08 |
| D5 | Staff bắt buộc xác thực hai lớp bằng **TOTP của Firebase Auth** (Identity Platform). Chủ studio không bắt buộc. | chủ dự án 2026-10-08 |
| D6 | Phía studio chỉ **chủ studio** dùng web (tài khoản `photographers` có `providerType = studio`). Thành viên dùng app. | spec studio 10-06 (không có vai trò quản lý) |
| D7 | Mọi thao tác của staff ghi vào collection chung `audit_log`, trong cùng transaction với quyết định. `awardAudit` và `verificationAudit` giữ nguyên. | spec chính §3i.6, data-model `AuditLog` |
| D8 | File riêng tư (giấy tờ, minh chứng, bằng chứng) chỉ xem qua callable `getSensitiveFileUrl`: kiểm vai trò, ghi audit, trả signed URL sống 5 phút. | — |
| D9 | Staff giữ use case S23, thêm S23.08–S23.11. Studio trên web là use case mới **S28**. | §6 |
| D10 | Không dùng listener realtime. Hàng đợi tự tải lại mỗi 30 giây khi tab đang mở và sau mỗi thao tác. | chi phí, đơn giản |

## 1. Mục tiêu và phạm vi

**Ai dùng.** Nhân viên nền tảng (vài người lúc ra mắt) và chủ studio.

**Thành công khi:**
1. Staff làm được mọi việc của S23 (tiền, xác minh, giải thưởng, khiếu nại, hỗ trợ, kiểm duyệt, cấu hình) trên web, không cần CLI hay Firebase console. Các CLI vẫn giữ để chữa cháy.
2. Chủ studio quản lý lịch, giao thợ, thành viên, bàn giao và kinh doanh trên máy tính.
3. Mọi quyết định của staff truy lại được: ai, lúc nào, lý do.
4. Sang phase 2 chỉ phải thay lớp đọc và địa chỉ gọi ghi của BFF, không viết lại màn hình.

**Ngoài phạm vi:** khách hàng và thành viên studio trên web; trang công khai; giao diện điện thoại cho staff; cổng thanh toán, ngân hàng, VNeID thật (vẫn là cổng giả như Phase 1); Go backend (phase 2).

## 2. Kiến trúc

```
Trình duyệt (React)
  ├─ firebase/auth: đăng nhập, TOTP, tự làm mới ID token
  └─ gọi server action / route handler, cookie __session = ID token
        │
Next.js server (BFF, apps/dashboard/src/server)
  ├─ auth/    verifyIdToken(checkRevoked) → guard vai trò, TOTP, chủ studio
  ├─ read/    interface đọc theo màn → adapter firestore/ (Admin SDK, chỉ đọc)
  └─ write/   callables.ts → POST callable với Bearer ID token của người dùng
        │                                   │
   Firestore (đọc)                Cloud Functions (callable, asia-southeast1)
                                     └─ packages/domain: luật, quyền, audit_log
```

### 2.1 Vị trí trong repo

```
apps/dashboard/
  package.json, tsconfig.json, next.config.ts, apphosting.yaml, eslint.config.js
  src/
    app/
      login/                       S23.08
      (staff)/staff/…              S23.xx (layout: StaffShell)
      (studio)/studio/…            S28.xx (layout: StudioShell)
      api/session/route.ts         đặt / xoá cookie __session
    server/                        chỉ chạy phía server (import 'server-only')
      auth/  session.ts, guards.ts
      read/  <màn>.ts (interface + DTO), firestore/<màn>.ts (adapter)
      write/ callables.ts, errors.ts
    components/                    thành phần web dùng chung (§8)
    lib/   screen-codes.ts, format.ts (tiền, ngày giờ), permissions.ts
    messages/vi.ts                 mọi chữ hiển thị
    styles/tokens.css              sinh từ design-system/tokens.json, không sửa tay
  test/  (Vitest), e2e/ (Playwright)
```

- `@photobooking/domain` được import qua `tsconfig` `paths` như Functions đang làm. Dashboard chỉ dùng **kiểu, hàm kiểm tra đầu vào, bảng quyền và nhãn**; không chạy use case ghi.
- Không có npm workspace ở gốc repo (giữ như hiện tại). `apps/dashboard` có `npm ci` riêng.

### 2.2 Phiên và luồng một request

1. Trình duyệt đăng nhập bằng `firebase/auth`. Mỗi khi `onIdTokenChanged` báo token mới, client `POST /api/session` với token đó. Route này `verifyIdToken` rồi đặt cookie `__session` (httpOnly, Secure, SameSite=Strict, `Max-Age` = thời hạn còn lại của token). Đăng xuất thì `DELETE /api/session`.
2. Mỗi request vào server component, server action hay route handler: `getSession()` đọc `__session`, gọi `verifyIdToken(token, checkRevoked = true)`, trả `{uid, staffRole?, secondFactor?, authTime}`. Token hết hạn thì trả 401, client làm mới token rồi thử lại một lần.
3. Guard theo route: `requireStaff(action)` (§4.2) hoặc `requireStudioOwner()` (đọc `photographers/{uid}`: `providerType = studio`). Không đủ quyền thì trả trang 403, không lộ dữ liệu.
4. Đọc: server component gọi reader của màn, nhận DTO.
5. Ghi: server action gọi `callCallable(name, data, token)` với **chính token trong cookie**. Callable kiểm lại quyền độc lập (không tin BFF), chạy use case, ghi `audit_log`.
6. Sau khi ghi: `revalidatePath` màn hiện tại; client hiện kết quả.

Chống CSRF: server action của Next.js đã kiểm `Origin`; route handler tự kiểm `Origin` và dùng cookie SameSite=Strict.

### 2.3 Lớp đọc

- Mỗi màn có một interface đọc trong `server/read/<màn>.ts` và DTO của nó. Adapter `server/read/firestore/<màn>.ts` dùng Admin SDK. Phase 2 thêm `server/read/http/` gọi Go; màn không đổi.
- DTO theo quy ước `data-model/README.md`: id là chuỗi, tiền là số nguyên VND (`amount` + không có số thực), thời điểm là chuỗi ISO UTC, enum là mã chuỗi. Không gửi `Timestamp` hay `DocumentReference` xuống trình duyệt.
- Danh sách phân trang bằng con trỏ (sau id hoặc sau thời điểm), mỗi trang 50 dòng. Số đếm hàng đợi dùng truy vấn `count()` (tính 1 lượt đọc cho mỗi 1.000 doc).
- Mỗi truy vấn mới kèm index trong `app_flutter/firebase/firestore.indexes.json`, do spec của từng ticket liệt kê.
- Dữ liệu nhạy cảm không đi qua lớp đọc: số tài khoản ngân hàng chỉ hiện 4 số cuối như app; số giấy tờ tuỳ thân chỉ 4 số cuối (spec xác minh 10-06); ảnh và file riêng tư qua `getSensitiveFileUrl` (§5.3).

### 2.4 Lớp ghi

- `callCallable<TIn, TOut>(name, data, idToken)`: `POST {CALLABLE_BASE_URL}/{name}`, header `Authorization: Bearer <idToken>`, body `{"data": …}`, đọc `{"result": …}` hoặc `{"error": {status, message, details: {code}}}`.
  - Production: `CALLABLE_BASE_URL = https://asia-southeast1-<projectId>.cloudfunctions.net`.
  - Emulator: `http://127.0.0.1:5001/<projectId>/asia-southeast1`.
  - Plan #162 kiểm URL này với callable 2nd gen trên emulator; nếu khác thì đổi trong `callables.ts`, màn không đổi.
- Lỗi: `details.code` là mã `DomainError` (`packages/domain/src/errors.ts`). `server/write/errors.ts` đổi mã sang câu tiếng Việt trong `messages/vi.ts`; mã lạ hiện câu chung kèm mã để báo lỗi.
- Mỗi thao tác ghi gửi kèm `idempotencyKey` (ULID tạo khi mở hộp xác nhận) cho callable nào có trường này, để bấm hai lần không chạy hai lần.
- App Check đang tắt cho callable. Nếu sau này bật, BFF cần token App Check riêng: ghi vào câu hỏi mở.

### 2.5 Làm mới dữ liệu

Không dùng listener. Màn hàng đợi gọi `router.refresh()` mỗi 30 giây khi tab đang hiện (`visibilitychange`), dừng khi tab ẩn; S23.09 Tổng quan làm mới mỗi 60 giây (§9, chi phí đọc). Sau mỗi thao tác ghi thì làm mới ngay. Hộp thư hỗ trợ (S23.06) có thể làm mới nhanh hơn, do spec #165 quyết.

### 2.6 Luật lint (ESLint `no-restricted-imports`)

- `firebase-admin`, `server-only` và mọi thứ trong `src/server/**` chỉ được import từ `src/server/**` và từ server component, server action, route handler.
- Code phía client cấm `firebase/firestore`, `firebase/storage`, `firebase/database`; chỉ được `firebase/app` và `firebase/auth`.
- Test kiểu "purity" như `packages/domain/test/purity.test.ts`: quét `src/` để chắc không file client nào import các gói trên.

### 2.7 Sang phase 2 (#98)

- Lớp đọc: thêm adapter `http/` gọi API Go, chọn bằng biến môi trường; bỏ adapter Firestore.
- Lớp ghi: `CALLABLE_BASE_URL` trỏ sang Go; tên thao tác giữ nguyên, Go cung cấp endpoint cùng tên và cùng dạng dữ liệu (`services/api` lấy `relational-schema.md` làm đích).
- Đăng nhập: vẫn Firebase Auth tới phase 3.

## 3. Đăng nhập và phiên

### 3.1 Cách đăng nhập

Giống app (S01.03): Google, Facebook, email và mật khẩu, bằng `firebase/auth` trên web. Không tạo tài khoản trên dashboard: tài khoản phải có sẵn từ app (staff được cấp vai trò sau, studio đã thiết lập hồ sơ ở S08).

### 3.2 TOTP cho staff

- Project nâng Firebase Auth lên **Identity Platform** và bật nhà cung cấp MFA TOTP (miễn phí dưới 50.000 MAU; không tốn SMS). Việc nâng làm cùng lúc với bật Blaze (D3); tới lúc đó chỉ chạy trên emulator với `MFA_DEV_BYPASS` nếu emulator không hỗ trợ TOTP.
- **Lần đầu** một tài khoản có `staffRole` đăng nhập mà chưa có TOTP: S23.08 bước "Thiết lập ứng dụng xác thực": hiện mã QR và mã bí mật (`TotpMultiFactorGenerator.generateSecret`), người dùng nhập mã 6 số để đăng ký. Chưa đăng ký xong thì không vào được màn staff nào.
- **Các lần sau:** đăng nhập bước một xong thì Firebase trả lỗi `auth/multi-factor-auth-required`; S23.08 hiện ô nhập mã 6 số.
- **Kiểm ở server:** token phải có `firebase.sign_in_second_factor === 'totp'`. Kiểm ở **cả** BFF (`requireStaff`) và callable staff (`assertStaff` trong Functions, §4.3).
- **Mất điện thoại:** admin dùng S23.10 "Đặt lại xác thực hai lớp" (callable `resetStaffMfa`, §5.2). Người đó đăng nhập lại và đăng ký TOTP mới. Admin cuối cùng mất TOTP thì chủ dự án đặt lại bằng CLI `npm run staff -- reset-mfa <uid>` (Admin SDK).
- **Emulator:** Auth emulator có thể không hỗ trợ TOTP; plan #162 kiểm việc này đầu tiên. Nếu không hỗ trợ: biến `MFA_DEV_BYPASS=1` cho phép bỏ kiểm bước hai, **chỉ có tác dụng** khi BFF chạy với `USE_EMULATORS=1` và khi Functions chạy trong emulator (`FUNCTIONS_EMULATOR=true`); ở mọi môi trường khác biến này bị bỏ qua và log cảnh báo.

### 3.3 Hạn phiên

- ID token sống 1 giờ, client tự làm mới.
- Staff: phải đăng nhập lại khi `auth_time` cũ hơn 12 giờ (BFF kiểm); đăng xuất sau 30 phút không thao tác (client đếm, hỏi trước 60 giây).
- Chủ studio: theo phiên Firebase thông thường, đăng nhập lại sau 30 ngày.
- Đổi hoặc bỏ vai trò staff thì `revokeRefreshTokens(uid)`; nhờ `checkRevoked`, phiên cũ hết hiệu lực ngay ở request kế tiếp.

### 3.4 Sau khi đăng nhập

| Tài khoản | Đi tới |
|---|---|
| Có `staffRole` | `/staff` (S23.09) |
| Chủ studio | `/studio` (S28.01, spec #167) |
| Cả hai | Trang chọn "Vào trang staff" / "Vào trang studio" (một dòng trên S23.08 sau đăng nhập) |
| Không phải hai loại trên | S23.08 trạng thái "Tài khoản này không dùng được dashboard", nút "Đăng xuất" |

## 4. Vai trò và quyền

### 4.1 Vai trò staff

- Claim `staffRole ∈ {admin, finance, support, sales}`, một giá trị. Code đang có kiểm `=== 'admin'` (`callables/award.ts`) và `admin | sales` (`callables/event.ts`, `firestore.rules` `staffIs`) vẫn đúng.
- Nguồn sự thật: `staff_members/{uid}` `{role, grantedBy, grantedAt, updatedAt}`. Claim là bản sao, do `setStaffRole` ghi cùng lúc (khớp `relational-schema.md`: bảng là nguồn, claim là bản sao).
- Luôn còn ít nhất một `admin`: `setStaffRole` từ chối bỏ hoặc hạ vai trò admin cuối cùng (mã lỗi `last_admin`).
- Seed emulator thêm tài khoản `finance.staff@seed.test`, `support.staff@seed.test`, `sales.staff@seed.test` và một chủ studio (ghi vào `functions/seed/README.md`).

### 4.2 Bảng quyền

Một bảng duy nhất trong `packages/domain/src/staff_permissions.ts`: `STAFF_ROLES`, kiểu `StaffAction` (mã chuỗi, ví dụ `payout.approve`) và `staffMay(role, action): boolean`. Functions dùng để kiểm, BFF dùng để chặn route và ẩn mục menu. Spec của từng ticket thêm các `StaffAction` của mình vào bảng này.

| Nhóm màn | admin | finance | support | sales |
|---|---|---|---|---|
| S23.09 Tổng quan | ✓ | ✓ | ✓ | ✓ (chỉ thấy hàng đợi của mình) |
| S23.02, S23.03 Tiền (chi trả, đối soát, hoàn, thuế) | ✓ | ✓ | — | — |
| S23.01 Khiếu nại: xem | ✓ | ✓ | ✓ | — |
| S23.01 Khiếu nại: quyết định thả / hoàn / chia | ✓ | — | ✓ | — |
| S23.04 Xác minh, S23.07 Giải thưởng (gồm xem giấy tờ, minh chứng) | ✓ | — | ✓ | — |
| S23.05 Kiểm duyệt, cờ tuyển thợ S27 | ✓ | — | ✓ | — |
| S23.06 Hộp thư hỗ trợ | ✓ | — | ✓ | ✓ |
| Sự kiện của nền tảng, gửi promo | ✓ | — | — | ✓ |
| Cấu hình Chụp ngay | ✓ | — | — | — |
| S23.10 Staff, S23.11 Nhật ký | ✓ | — | — | — |

Ai không có ✓ thì không thấy mục menu và nhận 403 nếu gõ thẳng URL. Finance không bao giờ thấy giấy tờ tuỳ thân hay bằng chứng khiếu nại (chỉ thấy số tiền và trạng thái của khiếu nại).

### 4.3 Kiểm quyền trong Functions

- Hàm dùng chung `assertStaff(request, action)` trong `functions/src/callables/staff.ts`: đọc `staffRole`, kiểm bước hai TOTP (§3.2), gọi `staffMay`. Sai thì `permission-denied` với `details.code` `staff_forbidden` hoặc `mfa_required`.
- Use case trong domain nhận `StaffActor {uid, role}` thay cho `{uid, isAdmin}` hiện tại (`payout_use_cases.ts`), và tự kiểm `staffMay` (để CLI cũng bị kiểm).
- CLI hiện có (`awards`, `payouts`) giữ cờ `--actor <uid>`, đọc vai trò của actor như cũ, qua `staffMay`.

### 4.4 Thay đổi so với plan Phase 1

Các plan sau đang ghi "chỉ admin". Khi viết plan cho ticket dashboard tương ứng (sau khi issue Phase 1 đã merge) thì đổi sang bảng ở §4.2:

| Plan / code | Hiện tại | Đổi thành |
|---|---|---|
| `reviewAward` (`callables/award.ts`, đã có) | admin | `award.review`: admin, support |
| `reviewVerification` (S21, #135) | admin | `verification.review`: admin, support |
| `resolveDispute` (S18, #142) | admin | `dispute.resolve`: admin, support |
| `npm run support -- reply` (S18) | admin, sales | `support.reply`: admin, support, sales |
| Use case chi trả (`payout_use_cases.ts`, S06 #134) | `isAdmin` | `payout.*`: admin, finance |
| Báo cáo `decideReport` (S20, #144) | admin | `report.decide`: admin, support |
| Sự kiện (`event.ts`) | admin, sales | không đổi |

## 5. Nhật ký kiểm toán, callable nền tảng, file riêng tư

### 5.1 `audit_log`

```
audit_log/{ulid}
  actorId      uid, hoặc "system" cho job định kỳ
  actorRole    admin | finance | support | sales | studio | system
  action       mã chuỗi, ví dụ "payout.approve", "staff.set_role", "file.view"
  entityType   ví dụ "payout", "dispute", "user", "award", "file"
  entityId
  reason       chuỗi 5–500 ký tự khi thao tác cần lý do, ngược lại null
  diff         object nhỏ {trường: [trước, sau]} hoặc null; không chứa số tài khoản, số giấy tờ
  at           thời điểm server
```

- Ghi qua port `AuditWriter` mới trong `packages/domain/src/audit.ts` (`add(entry)` trong transaction của use case). Adapter Firestore trong `functions/src/infra/audit_firestore.ts`.
- Mỗi callable staff mới (của #161 và các ticket sau) ghi đúng một dòng cho mỗi quyết định. `reviewAward` ghi thêm `audit_log` ngoài `awardAudit` để S23.11 đủ.
- Không bao giờ xoá. Rules: client không đọc, không ghi (thêm test vào `rules-test`).
- Index: `(entityType, entityId, at desc)`, `(actorId, at desc)`, `(action, at desc)`.
- Cập nhật `data-model/domain-model.md` (`AuditLog` thêm `actorRole`, `reason`) và `relational-schema.md` (`audit_log` thêm `actor_role`, `reason`).

### 5.2 Callable mới của #162

| Callable | Ai gọi | Đầu vào | Làm gì |
|---|---|---|---|
| `setStaffRole` | `staff.set_role`: admin | `{uid, role: StaffRole \| null, reason}` | Ghi `staff_members/{uid}` (xoá khi `null`), đặt claim, `revokeRefreshTokens`, audit. Từ chối hạ admin cuối cùng. |
| `resetStaffMfa` | `staff.reset_mfa`: admin | `{uid, reason}` | Xoá mọi second factor của `uid` (Admin SDK `updateUser`), `revokeRefreshTokens`, audit. |
| `findUserForStaff` | `staff.set_role`: admin | `{email}` | Trả `{uid, displayName, email, staffRole}` của đúng một tài khoản, hoặc `not_found`. Không có tìm kiếm mờ. |
| `decideStaffApproval` | theo `kind` (§5.4) | `{approvalId, decision, note}` | Duyệt hoặc từ chối một yêu cầu hai người; duyệt thì chạy thao tác gốc. |
| `cancelStaffApproval` | người đề xuất | `{approvalId}` | Huỷ yêu cầu còn `pending`. |
| `getSensitiveFileUrl` | theo `kind` | `{kind, entityId, file}` | Kiểm quyền theo bảng `kind` dưới, đổi `kind` + `entityId` + `file` sang đường dẫn Storage (không nhận đường dẫn tự do), ký URL đọc sống 5 phút, audit `file.view`. |

`kind` của `getSensitiveFileUrl` (ticket sau thêm vào bảng khi cần):

| `kind` | Đường dẫn | Quyền |
|---|---|---|
| `award_proof` | `awardProofs/{uid}/{awardId}/{file}` | `award.review` |
| `business_doc` | `businessDocs/{uid}/{file}` (S21) | `verification.review` |
| `dispute_evidence` | `disputeEvidence/{uid}/{disputeId}/{fileId}` (S18); chỉ ký khi đường dẫn nằm trong `disputes/{id}.evidencePaths` | `dispute.view` |

Thêm CLI `npm run staff -- list | set-role <uid> <role|none> --reason "…" | reset-mfa <uid>` (Admin SDK, chạy với service account) để tạo admin đầu tiên và chữa cháy.

### 5.3 File riêng tư trên màn

`SecureFileViewer` (§8) gọi server action → `getSensitiveFileUrl` mỗi lần mở file; URL không lưu lại, không đặt vào link chia sẻ. Ảnh hiện trong khung xem có watermark chữ "Nội bộ · <email staff> · <thời điểm>" bằng CSS (lớp phủ, không sửa file) để ảnh chụp màn hình truy được nguồn.

### 5.4 Duyệt hai người (`staff_approvals`)

Một số thao tác cần người thứ hai xác nhận: thao tác tiền từ 10.000.000₫ (`screens/staff-money.md` §2) và khôi phục xác minh đã thu hồi (`screens/staff-verification-awards.md`). Cơ chế dùng chung:

```
staff_approvals/{ulid}
  kind          mã thao tác, ví dụ payout_approve, refund_manual, verification_reinstate
  entityType, entityId
  amount?       số đồng, khi là thao tác tiền
  params        đầu vào của thao tác (đã kiểm), không chứa số tài khoản hay số giấy tờ
  reason        lý do của người đề xuất
  status        pending | approved | rejected | cancelled | expired
  requestedBy, requestedRole, requestedAt, expiresAt (= requestedAt + 24 giờ)
  decidedBy?, decidedAt?, decisionNote?
```

- Bảng `APPROVAL_KINDS` trong `packages/domain/src/staff_approvals.ts`: với mỗi `kind`, `StaffAction` để đề xuất, `StaffAction` để duyệt, và hàm chạy thao tác gốc. Ticket nào thêm thao tác cần hai người thì thêm một dòng vào bảng này.
- Callable của thao tác gốc tạo yêu cầu `pending` khi luật của thao tác đòi hai người, trả `{status: 'awaiting_second_approval', approvalId}`. Mỗi đối tượng có tối đa một yêu cầu `pending` (`approval_pending`).
- `decideStaffApproval({approvalId, decision: 'approve' | 'reject', note})`: người duyệt có quyền duyệt của `kind` và khác người đề xuất (`same_person`). `approve` chạy thao tác gốc với `params` đã lưu trong cùng transaction, kiểm lại trạng thái đối tượng; đối tượng đã đổi thì yêu cầu thành `rejected` với ghi chú hệ thống (`stale`). Quá `expiresAt` thì `expired`.
- `cancelStaffApproval({approvalId})`: chỉ người đề xuất, khi còn `pending`.
- `audit_log`: một dòng cho đề xuất (`approval.request`), một cho quyết định (`approval.decide`), một cho thao tác gốc (actor là người duyệt, `diff` ghi cả hai uid).
- Rules: client không đọc, không ghi. Index `(status, requestedAt)`, `(entityType, entityId, status)`.
- CLI không có người thứ hai: thao tác cần hai người chạy bằng CLI cũng chỉ tạo yêu cầu.

## 6. Mã màn

- Staff: thêm vào S23 (bảng mã §2 của spec chính, cột Route ghi route web):

  | Mã | Màn | Route | Vai trò |
  |---|---|---|---|
  | S23.08 | Đăng nhập dashboard & xác thực hai lớp (staff và chủ studio) | `/login` | staff · studio |
  | S23.09 | Tổng quan staff: các hàng đợi, số việc, việc quá hạn | `/staff` | mọi staff |
  | S23.10 | Staff: cấp, đổi, bỏ vai trò; đặt lại xác thực hai lớp | `/staff/team` | admin |
  | S23.11 | Nhật ký kiểm toán | `/staff/audit` | admin |
  | S23.15 | Chờ duyệt lần hai (§5.4; mã cấp ở spec #163) | `/staff/approvals` | ai có quyền duyệt ít nhất một `kind` |

  S23.01–S23.07 có route web khi spec ticket của chúng chốt (ví dụ `/staff/payouts`). Mã mới cho màn staff còn lại lấy tiếp từ S23.12 theo thứ tự viết spec ticket.
- Studio: use case mới **S28 · Studio trên web**; mã S28.yy do spec #167 và #169 cấp.
- Dashboard có `src/lib/screen-codes.ts` riêng (không thêm vào `lib/core/screen_codes.dart` của app). Mỗi trang bọc `<ScreenCode code="S23.09">`; bật Debug (`?debug=1`, chỉ ở môi trường dev) thì hiện nhãn mã ở góc trên trái như app.

## 7. Màn khung

### S23.08 · Đăng nhập & xác thực hai lớp

- **Thông tin:** `/login` · staff, chủ studio · chưa có.
- **Mục đích:** vào dashboard đúng quyền, staff qua được bước TOTP.
- **Điểm vào → ra:** mở dashboard khi chưa có phiên, hết phiên, bị thu hồi → §3.4.
- **Bố cục:** khung giữa màn hình trên nền aurora, rộng 400. Logo, tiêu đề "Dashboard", nút "Tiếp tục với Google", "Tiếp tục với Facebook", dải phân cách, ô email + mật khẩu, nút chính "Đăng nhập". Bước TOTP thay nội dung khung: tiêu đề "Nhập mã xác thực", ô 6 số (tự nhảy ô, dán được), nút chính "Xác nhận". Bước thiết lập: 1. tải ứng dụng xác thực, 2. mã QR + mã bí mật (nút sao chép), 3. ô 6 số, nút chính "Bật xác thực hai lớp".
- **Trạng thái:** đang đăng nhập (nút `loading`); sai mật khẩu; sai mã 6 số ("Mã không đúng hoặc đã hết hạn"); quá nhiều lần thử (thông điệp từ Firebase `auth/too-many-requests`); tài khoản không dùng được dashboard; phiên hết hạn ("Phiên đã hết, đăng nhập lại").
- **Tương tác:** Enter gửi; mã 6 số đủ thì tự gửi.
- **Chấp nhận:** staff không có TOTP không vào được `/staff/*`; token không có bước hai bị BFF và callable từ chối; chủ studio vào `/studio` không cần TOTP.

### S23.09 · Tổng quan staff

- **Thông tin:** `/staff` · mọi staff · chưa có.
- **Mục đích:** biết hàng đợi nào cần làm ngay.
- **Bố cục:** `StaffShell`. Tiêu đề "Tổng quan" + ngày. Lưới thẻ hàng đợi (chỉ các hàng đợi vai trò được xem): tên, số việc đang mở (số lớn), số quá hạn (chip đỏ "3 quá hạn"), tuổi việc cũ nhất ("Cũ nhất 26 giờ"), cả thẻ là link sang hàng đợi. Bên dưới: "Thao tác gần đây của bạn" (5 dòng cuối trong `audit_log` của chính người đó).
- **Dữ liệu:** mỗi thẻ là một `count()` + một truy vấn lấy việc cũ nhất. Hạn quá hạn của từng hàng đợi do spec ticket chốt (ví dụ xác minh 24 giờ, giải thưởng 3 ngày làm việc). Ticket nào chưa xong thì thẻ của nó không hiện.
- **Trạng thái:** skeleton thẻ; mọi hàng đợi trống: `EmptyState` "Không còn việc nào đang chờ"; lỗi một thẻ chỉ hiện lỗi trong thẻ đó.
- **Chấp nhận:** sales chỉ thấy thẻ hộp thư; finance chỉ thấy thẻ tiền và khiếu nại (chỉ xem).

### S23.10 · Staff

- **Thông tin:** `/staff/team` · admin · chưa có.
- **Mục đích:** cấp và thu hồi quyền staff an toàn.
- **Bố cục:** tiêu đề "Staff", nút chính "Thêm staff". Bảng: tên, email, vai trò (`StatusChip`), xác thực hai lớp (Đã bật / Chưa bật), cấp bởi, ngày cấp, menu "…" (Đổi vai trò, Đặt lại xác thực hai lớp, Bỏ quyền staff).
- **Tương tác:** "Thêm staff" mở `DecisionDialog`: ô email → `findUserForStaff` → hiện tên tài khoản → chọn vai trò → lý do → "Cấp quyền". "Bỏ quyền staff" và "Đặt lại xác thực hai lớp" là nút đỏ trong hộp xác nhận, bắt lý do.
- **Trạng thái:** không tìm thấy email; người đó đã là staff (chuyển sang đổi vai trò); `last_admin`.
- **Chấp nhận:** mỗi thao tác tạo đúng một dòng `audit_log`; người bị bỏ quyền mất quyền ở request kế tiếp.

### S23.11 · Nhật ký kiểm toán

- **Thông tin:** `/staff/audit` · admin · chưa có.
- **Mục đích:** tra ai đã làm gì với một đối tượng.
- **Bố cục:** bộ lọc: người thao tác, loại đối tượng + id, thao tác, khoảng ngày. Bảng: thời điểm, người (tên + vai trò), thao tác (nhãn tiếng Việt từ mã), đối tượng (link sang màn chi tiết nếu có), lý do. Bấm dòng mở chi tiết với `diff`.
- **Dữ liệu:** truy vấn theo một trong ba index ở §5.1; mỗi trang 50 dòng; không có tìm kiếm toàn văn.
- **Chấp nhận:** lọc theo `entityType + entityId` cho ra toàn bộ lịch sử của đối tượng đó theo thời gian giảm dần.

### S23.15 · Chờ duyệt lần hai

- **Thông tin:** `/staff/approvals` · staff có quyền duyệt ít nhất một `kind` (§5.4) · chưa có.
- **Mục đích:** người thứ hai xem và xác nhận một thao tác cần hai người.
- **Bố cục:** `QueueLayout`, chỉ liệt kê `kind` người xem được duyệt, cộng các yêu cầu của chính mình. Bảng: thao tác (nhãn), đối tượng, số tiền (khi có), người đề xuất + vai trò, còn hạn ("còn 18 giờ"). `DetailPane`: lý do của người đề xuất, tóm tắt thao tác (như hộp xác nhận gốc), link sang đối tượng. Chân: chính "Duyệt", phụ "Từ chối…" (đỏ trong hộp, bắt ghi chú). Yêu cầu của chính mình: chỉ "Huỷ yêu cầu".
- **Trạng thái:** trống "Không có thao tác nào chờ duyệt"; `same_person`; `stale` ("Đối tượng đã thay đổi, yêu cầu đã đóng"); `expired`.
- **Chấp nhận:** người đề xuất không duyệt được yêu cầu của mình kể cả gọi thẳng callable; thao tác gốc chạy đúng một lần.

### Khung studio

`StudioShell` có cùng cấu trúc với `StaffShell`; mục menu: Tổng quan, Lịch, Booking, Bàn giao, Thành viên, Gói dịch vụ, Báo giá, Thu nhập, Đánh giá, Tin nhắn. Nội dung từng mục thuộc spec #167 và #169.

## 8. Bố cục chung và thành phần web

- **Theme:** dark aurora mặc định, có sáng; màu 60-30-10 (tím chỉ cho nút chính, mục đang chọn, link, tiêu điểm); icon Material Symbols Rounded; chữ Be Vietnam Pro, tiêu đề Fraunces. `styles/tokens.css` sinh bằng `tool/gen_tokens_css.mjs` (mới, nằm trong repo, thay cho script ngoài repo mà `design-system/README.md` đang nhắc) từ `design-system/tokens.json`; CI báo lỗi khi file sinh ra cũ (giống kiểm `tokens.g.dart`).
- **Kích thước:** staff dùng tốt từ 1024 px trở lên (dưới 1024 hiện thanh "Dashboard staff cần màn hình rộng hơn" nhưng vẫn đọc được). Studio dùng tốt từ 768 px (tablet); dưới 768 thanh bên thu thành menu.
- **`StaffShell` / `StudioShell`:** thanh bên trái 248 px, nhóm mục (staff: Hàng đợi · Tiền · Nội dung · Hệ thống), mỗi hàng đợi có số đếm, đỏ khi có việc quá hạn; thanh trên: ô "Tìm theo mã" (dán id booking, người dùng, thanh toán, khiếu nại → mở chi tiết), chip vai trò, menu tài khoản (Đăng xuất).
- **Mẫu hàng đợi (`QueueLayout`):** cột trái là `DataTable` có bộ lọc, mặc định sắp việc quá hạn rồi việc cũ nhất lên đầu; cột phải là `DetailPane`. Chân `DetailPane` có **một** nút chính (ví dụ "Duyệt") và nút phụ. Phím `j`/`k` chuyển dòng, `Enter` mở.
- **`DecisionDialog`:** mọi quyết định động tới tiền hoặc trạng thái mở hộp này: tóm tắt việc sẽ xảy ra (số tiền, ai nhận), ô lý do bắt buộc 5–500 ký tự, nút xác nhận. Từ chối, huỷ, hoàn tiền, thu hồi là **nút đỏ trong hộp**, không bao giờ là nút gradient.
- **Thành phần:** `StaffShell`, `StudioShell`, `QueueLayout`, `DataTable` (cột, sắp, phân trang con trỏ), `DetailPane`, `DecisionDialog`, `StatusChip` (màu + chữ), `MoneyText` (`1.500.000₫`, số đều), `DateTimeText` (`T7 12/10 15:30`, Asia/Ho_Chi_Minh), `SecureFileViewer`, `EmptyState`, `ErrorState` (có "Thử lại"), `Skeleton` theo hình khối từng thành phần, `AsyncView` với `DotRingLoader` (vòng chấm xoay, chuyển từ CSS của mock), `Toast`. Ghi vào `components/shared-components.md` mục "Web (dashboard)".
- **Chữ:** tiếng Việt trong `src/messages/vi.ts`, khoá theo màn (`s23_09.title`) và khoá chung (`common.retry`); không viết chữ cứng trong component (lint `react/jsx-no-literals` cho `src/app` và `src/components`).
- **Truy cập:** đạt WCAG 2.2 AA về tương phản; mọi thao tác làm được bằng bàn phím; tiêu điểm thấy rõ (`--focus`); trạng thái luôn có chữ, không chỉ màu; tôn trọng `prefers-reduced-motion`.

## 9. Deploy, môi trường, chi phí

- **Local:** `../scripts/backend-local.sh` (emulator + seed), rồi trong `apps/dashboard`: `npm run dev` với `USE_EMULATORS=1` (Admin SDK đọc `FIRESTORE_EMULATOR_HOST`, `FIREBASE_AUTH_EMULATOR_HOST`; callable trỏ functions emulator).
- **Blaze tắt (hiện tại):** chỉ có cách chạy local ở trên. Mọi thứ cần Blaze mà dashboard dùng (App Hosting, Cloud Functions cho mọi thao tác ghi và URL ký, Storage cho file riêng tư và tệp xuất, Identity Platform) chỉ có trên emulator. Không thêm bước deploy nào ngoài công tắc `BLAZE_ENABLED`.
- **App Hosting (khi bật Blaze):** backend `dashboard`, region `asia-southeast1`, `apphosting.yaml`: `runConfig.minInstances: 0`, `maxInstances: 2`, `concurrency: 80`; biến `CALLABLE_BASE_URL`, `FIREBASE_PROJECT_ID`. Không có secret: Admin SDK dùng service account của backend.
- **Service account của backend:** chỉ `roles/datastore.viewer` và `roles/firebaseauth.viewer` (cho `checkRevoked`). Không có quyền Storage: mọi URL ký đi qua callable.
- **CI:**
  - Workflow mới `.github/workflows/dashboard.yml` (chạy khi đổi `apps/dashboard/**`, `packages/domain/**`, `design-system/**`): `npm ci`, lint, typecheck, Vitest, `next build`, kiểm `tokens.css` không cũ; job Playwright chạy trên emulator như `functions-test`.
  - `firebase-deploy.yml` thêm job `deploy-dashboard` sau `deploy-functions` (`firebase deploy --only apphosting:dashboard`), cùng môi trường `dev` / `production`; chạy cùng điều kiện với `deploy-functions`: có `FIREBASE_PROJECT_ID` **và** `BLAZE_ENABLED` = `true`; ngược lại chỉ in cảnh báo.
- **Chi phí** (đơn giá theo `2026-10-07-google-cloud-costs.md`, Cloud Run Tier 2; ước tính, sai số cao):
  - Dashboard ít người dùng (5 staff, 8 giờ/ngày; vài chục chủ studio), `minInstances: 0`: thời gian chạy nằm trong hạn mức miễn phí của Cloud Run → **~$0/tháng**, cold start vài trăm ms.
  - Đọc Firestore: 5 staff × 8 giờ × 120 lần làm mới/giờ × ~10 truy vấn (`count()` + trang đầu) ≈ 48.000 lượt/ngày, chạm hạn mức miễn phí 50.000/ngày. Vì vậy: chỉ làm mới màn đang mở (không làm mới thẻ tổng quan ở tab ẩn), và S23.09 làm mới mỗi 60 giây thay vì 30. Phần vượt (nếu có) ≈ $0,06/100K đọc → **< $1/tháng** ở cả mức 1.000 và 10.000 người dùng app.
  - Identity Platform: miễn phí dưới 50.000 MAU; TOTP không tốn SMS → **$0**.
  - Callable thêm: vài nghìn lần/tháng, trong hạn mức → **$0**.

## 10. Kiểm thử

- **Domain (`packages/domain`):** `staffMay` dạng bảng (mỗi vai trò × mỗi `StaffAction`); `AuditWriter` được gọi đúng một lần cho mỗi quyết định; `StaffActor` mới cho use case chi trả.
- **Functions:** unit + integration cho `setStaffRole` (cấp, đổi, bỏ, `last_admin`, revoke), `resetStaffMfa`, `findUserForStaff`, `getSensitiveFileUrl` (từng `kind` × vai trò, `kind` lạ, đường dẫn không đúng chủ), `assertStaff` (thiếu TOTP → `mfa_required`; `MFA_DEV_BYPASS` không có tác dụng ngoài emulator).
- **Rules (`rules-test`, CI chạy):** client không đọc/ghi `audit_log`, `staff_members`, `staff_approvals`.
- **Dashboard (Vitest):** `getSession` (token hết hạn, bị thu hồi, thiếu bước hai, `auth_time` > 12 giờ); guard theo bảng quyền; `callCallable` (đổi `details.code` sang chữ, lỗi mạng); mapper DTO (không lọt `Timestamp`); test purity import.
- **React Testing Library:** `QueueLayout`, `DecisionDialog` (lý do < 5 ký tự thì không gửi, nút đỏ cho từ chối), S23.10 luồng thêm staff.
- **Playwright trên emulator (CI):** đăng nhập từng tài khoản seed → thấy đúng menu; gõ URL ngoài quyền → 403; admin cấp vai trò `support` cho một tài khoản → tài khoản đó vào được hàng đợi xác minh, không vào được tiền; S23.11 hiện dòng vừa ghi.

## 11. Cập nhật tài liệu khác (cùng commit với spec này)

- Spec chính §2: thêm S23.08–S23.11, đổi cột Vai trò của S23.01–S23.07 theo §4.2, thêm tiêu đề S28; §3i.6 ghi đã chốt nền tảng; §8 câu 18 và 22 ghi đã chốt.
- `screens/README.md`: mục lục thêm các tệp spec dashboard; ghi rằng quy ước chung về code Flutter không áp dụng cho dashboard (dashboard theo §8 ở đây).

Phần đổi `data-model` (§5.1), `shared-components.md` (§8) và `design-system/README.md` làm trong plan #162 cùng code.

## 12. Câu hỏi mở (có mặc định, không chặn)

| # | Câu hỏi | Mặc định |
|---|---|---|
| Q1 | Tên miền của dashboard? | Dùng tên miền App Hosting cấp sẵn tới khi có tên miền chính |
| Q2 | Một người vừa là staff vừa là chủ studio? | Cho phép, chọn trang sau khi đăng nhập (§3.4) |
| Q3 | Auth emulator có hỗ trợ TOTP? | Plan #162 kiểm đầu tiên; không thì dùng `MFA_DEV_BYPASS` (§3.2) |
| Q4 | URL `cloudfunctions.net` có gọi được callable 2nd gen? | Plan #162 kiểm; khác thì đổi trong `callables.ts` |
| Q5 | Bật App Check cho callable khi nào? | Chưa bật; khi bật, BFF dùng App Check token của server |
| Q6 | Chủ studio có bắt buộc TOTP khi studio có doanh thu lớn? | Không bắt buộc, khuyến khích bật |

## 13. Thứ tự gợi ý cho plan #162

1. Domain: `staff_permissions.ts` (`STAFF_ROLES`, `StaffAction`, `staffMay`), `audit.ts` (`AuditWriter`), `StaffActor {uid, role}` cho use case chi trả.
2. Functions: `assertStaff`, adapter `audit_log`, `staff_approvals` (§5.4) với `decideStaffApproval`/`cancelStaffApproval`, `setStaffRole`, `resetStaffMfa`, `findUserForStaff`, `getSensitiveFileUrl`, CLI `staff`, rules + index, seed bốn tài khoản.
3. Kiểm hai câu hỏi Q3, Q4 trên emulator.
4. `apps/dashboard`: dựng dự án, lint import, `tool/gen_tokens_css.mjs`, thành phần dùng chung, `StaffShell`/`StudioShell`.
5. Phiên: `/api/session`, `getSession`, guard, S23.08 (đăng nhập, thiết lập và nhập TOTP).
6. Lớp đọc + `callCallable`; S23.09, S23.10, S23.11, S23.15.
7. CI `dashboard.yml`, `apphosting.yaml`, job `deploy-dashboard` sau công tắc `BLAZE_ENABLED` (không deploy khi công tắc tắt).
8. Playwright trên emulator.
