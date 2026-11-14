# Handover ledger — #162 nền tảng dashboard web (S23.08–S23.11, S23.15)

Plan: `docs/superpowers/plans/2026-11-14-162-dashboard-foundation.md`. Spec: `docs/superpowers/specs/2026-10-08-dashboard-web-design.md`. Mock: `docs/design/dashboard-mock.html`.

Đơn vị chạy trên hai repo, cùng tên nhánh `plan/162-dashboard-foundation`:

- **booking-be** (code: `packages/domain`, `firebase/functions`, `firebase/firestore.rules`, `apps/dashboard`, CI), merge trước. Tên trong file này lấy từ code ở đó.
- **booking**: PR này, chỉ tài liệu (Task 13).

## Hiện có gì

- **Domain** (`packages/domain/src`): `staff_permissions.ts` (`STAFF_ROLES` = `admin` · `finance` · `support` · `sales`; `STAFF_ACTIONS`; `staffMay`), `staff_members.ts` (`setStaffRole`, `resetStaffMfa`, `findUserForStaff`, `assertStaffCaller`), `staff_approvals.ts` (`APPROVAL_KINDS`, `requestApproval`, `decideApproval`, `cancelApproval`, `canApproveAny`, `canRequestAny`), `audit.ts` (`AuditWriter`, `validateReason`, `AuditActorRole`).
- **Hành động** `StaffAction` hiện có: `overview.view` (mọi vai trò), `staff.set_role`, `staff.reset_mfa`, `audit.view` (admin), `payout.manage` (admin, finance), `award.review`, `verification.review`, `dispute.evidence.view` (admin, support).
- **Callable**: `setStaffRole`, `resetStaffMfa`, `findUserForStaff`, `decideStaffApproval`, `cancelStaffApproval`, `getSensitiveFileUrl`. Kiểm theo thứ tự: bước hai TOTP (`mfa_required`), rồi `staffMay` (`staff_forbidden`).
- **Firestore** (chỉ server, rules từ chối mọi đọc ghi từ client): `staff_members/{uid}` (nguồn sự thật của vai trò; custom claim `staffRole` là bản sao), `staff_approvals/{id}`, `staff_approval_locks/{entityType}:{entityId}`, `audit_log/{ulid}` (thêm `actorRole`, `reason`). Chỉ mục tổ hợp `staff_approvals` `(status, requestedBy)` và `(status, kind)`. Bản quan hệ ở `specs/data-model/relational-schema.md`.
- **Dashboard** `apps/dashboard` (Next.js 16): đăng nhập + TOTP (S23.08), Tổng quan (S23.09), Staff/Team (S23.10), Nhật ký (S23.11), Chờ duyệt (S23.15), khung `StaffShell` và `StudioShell`. Component ở `specs/components/shared-components.md` mục "Web (dashboard)"; token CSS ở `design-system/README.md` mục 7.
- **CLI** `npm run staff` (`firebase/functions/tools/staff.ts`): chạy với `actorId` `cli:<user>`, `actorRole` `admin`, không qua vai trò của người gọi; vẫn ghi audit.
- **CI**: `.github/workflows/dashboard.yml` (jobs `checks`, `e2e` Playwright trên emulator) và job `deploy-dashboard` trong `firebase-deploy.yml`, sau Blaze switch.

## Kết quả Task 0 (emulator)

- **TOTP không chạy trên Auth emulator**: `generateSecret` trả `auth/invalid-argument` "Missing phoneEnrollmentInfo."; emulator chỉ hiểu đăng ký điện thoại và bỏ qua cấu hình `mfa`. Mã MFA chỉ chạy thật với Identity Platform (Blaze).
- URL callable trên emulator `http://127.0.0.1:<cổng functions>/<project>/asia-southeast1/<tên>` chạy được cho callable thế hệ 2 (200 có token, 401 không token). Dạng production `https://asia-southeast1-<project>.cloudfunctions.net/<tên>` chưa kiểm cho đến khi có Blaze (chỉ `CALLABLE_BASE_URL` đổi).
- Cổng 8080 và 9099 trên máy này đã bị emulator khác chiếm; đã chạy trên cổng thay thế. Lần chạy `backend-local.sh` đầu đã seed `demo-nag` vào emulator đang chạy sẵn đó.

## Rulings (mỗi dòng một quyết định)

1. **MFA_DEV_BYPASS**: chạy local, test tích hợp Functions và Playwright đặt `MFA_DEV_BYPASS=1`; màn TOTP vẫn có nhưng chỉ chạy thật với Blaze; spec Playwright "gọi callable không có totp" bị bỏ qua có in lý do (đã chạy riêng với bypass tắt: `mfa_required`).
2. `requestApproval` đóng yêu cầu `pending` đã quá `expiresAt` thành `expired` (actor `system`, audit `approval.expire`) trong cùng giao dịch rồi tạo yêu cầu mới.
3. `setStaffRole` trên dòng không đổi vẫn sửa claim bị lệch (`StaffAuth.getRoleClaim`): đặt lại claim, thu hồi phiên, không ghi audit.
4. Bỏ vai trò được phép khi dòng `staff_members` còn dù user Auth đã mất (bỏ qua bước Auth); `countAdmins` phải đọc admin trong giao dịch, không dùng `count()`; đổi vai trò giữ `grantedBy`/`grantedAt`; `findUserForStaff` lấy `staffRole` từ `staff_members`.
5. Id khoá duyệt là `${entityType}:${entityId}` (`:` không có trong hai bảng chữ cái; `approvalLockId` ném lỗi nếu có); chỉ xoá khoá khi nó còn trỏ đúng yêu cầu đang đóng.
6. `MFA_DEV_BYPASS` chỉ có hiệu lực khi `FUNCTIONS_EMULATOR=true`; test chặn việc đặt nó (hay `FUNCTIONS_EMULATOR`) trong mọi `firebase/functions/.env*` đã commit (chỉ `.env.local`, bị gitignore, được đặt).
7. Hành động xem minh chứng khiếu nại tên **`dispute.evidence.view`** (admin, support), không phải `dispute.view`: `dispute.view` để dành cho danh sách/chi tiết của #142 (có finance), nên "finance không bao giờ thấy minh chứng" là cấu trúc. **Spec `screens/staff-disputes-support.md` còn dùng `dispute.view` cho xem đầy đủ: cần đối chiếu khi làm #165.**
8. Minh chứng giải thưởng chỉ ký những đường dẫn có trong `awardProofs/{awardId}.files[].storagePath`; ký trước, ghi audit `file.view`, rồi trả URL; cổng staff chạy trước khi kiểm `kind`.
9. Tường import là danh sách cho phép: ngoài `src/server` chỉ `firebase/app` và `firebase/auth` trong họ firebase; `import()` động cũng bị kiểm (ESLint + `test/purity.test.ts`); mọi file `src/server/**` import `server-only`.
10. `DecisionDialog` bắt lỗi từ chối, mở khoá và hiện lỗi trong dòng `role="alert"`; thứ tự sắp xếp nằm ở `QueueLayout` để `j`/`k` đi theo hàng đang hiện.
11. TOTP issuer là "Nhiếp Ảnh Gia" (mock là nguồn chữ, thắng plan); `?step=totp` đi qua `enter(user)` để server quyết định.
12. Huỷ yêu cầu duyệt dùng `DecisionDialog` với `reasonMode='none'` (callable `cancelStaffApproval({approvalId})` giữ nguyên); `DecisionDialog` thêm `confirmDisabled` và `initialFocus`.
13. `/staff/approvals` và mục menu chỉ cho `canApproveAny(role) || canRequestAny(role)`; vai trò khác nhận 403. Spec dashboard dòng S23.15 đã sửa theo.
14. Hai chỉ mục tổ hợp của `staff_approvals` khai báo trong `firestore.indexes.json`, test kiểm có chỉ mục khớp như audit.
15. Server action ghi gọi `requireStaff('<action>')` trước (phiên đăng nhập trong 12 giờ); `runCallable` đổi mọi lỗi không phải `CallableError` thành `{ok:false, code:'internal'}`, chỉ log mã.

**Quy ước và quyết định kèm theo (từ plan)**

- **`.client.tsx`**: file `'use client'` phải tên `*.client.tsx` (hoặc `*.client.ts`); file `.client` không import `src/server`. Xem `shared-components.md`, mục "Web (dashboard)".
- **Tệp riêng tư trên emulator**: emulator Storage không ký được URL, nên `signed_url.ts` trả chính tệp dưới dạng URL `data:<type>;base64,...`; mọi nơi dùng coi URL là mờ. Production ký thật, cần quyền `iam.serviceAccounts.signBlob` cho tài khoản dịch vụ của Functions. Đường `data:` chưa chạy trên emulator thật (Task 5 chưa kiểm).
- **`payout.manage` mở chi trả cho finance**: các use case chi trả kiểm bằng `staffMay(role, 'payout.manage')` (admin, finance) thay cho `isAdmin`; CLI chi trả vẫn nhận `--actor <uid>`; job `createPayouts` chạy bằng actor `system:createPayouts`.
- **CLI chạy là `cli:<user>`**: `npm run staff` (`tools/staff.ts`, `cliCaller`) gọi use case với người gọi `{uid: 'cli:<user hệ điều hành>', role: 'admin', mfa: true}`, không có đăng nhập và không qua vai trò của ai; audit ghi `actorId` `cli:<user>`, `actorRole` `admin`. CLI chi trả `npm run payouts` giữ cờ `--actor <uid>` (phải có claim `staffRole` = admin hoặc finance).

## Các ticket sau thêm gì

Mỗi ticket sửa `packages/domain/src/staff_permissions.ts` (thêm vào `STAFF_ACTIONS` và bảng `ALLOWED`: mọi hành động mới phải có một dòng nếu không `typecheck` lỗi, test bảng quyền phải cập nhật), thêm mục vào `STAFF_NAV` (`nav.ts`, có `action`) và thẻ vào S23.09. Id resolver đăng ký bằng `registerIdResolver` (`src/lib/id-resolvers.ts`) khi module client của ticket được nạp; resolver trả route chi tiết hoặc `null`, khớp đầu tiên thắng. Danh sách lấy từ các spec `screens/` (đối chiếu lại khi viết plan ticket):

| Ticket | `StaffAction` thêm | `APPROVAL_KINDS` thêm | Thẻ S23.09 | Tìm theo mã |
|---|---|---|---|---|
| #163 Tiền (`staff-money.md`) | admin + finance: `payout.view`, `payout.approve`, `payout.hold`, `payout.resume`, `payout.execute`, `transfer.view`, `transfer.assign`, `transfer.refund`, `transfer.dismiss`, `refund.view`, `refund.retry`, `refund.mark_manual`, `instant.staff_cancel`, `tax.view`, `tax.export`, `money_approval.decide` | thao tác tiền từ 10 triệu (spec S23.15); duyệt bằng `money_approval.decide` | số hàng đợi chi trả, chuyển khoản chưa khớp, hoàn tiền lỗi; số chờ duyệt trên thanh bên | spec chưa nêu mã riêng |
| #164 Xác minh và giải thưởng (`staff-verification-awards.md`) | admin + support: `verification.view`, `verification.review`, `verification.revoke`, `award.view`, `award.review`; admin: `verification.reinstate.request`; admin + support: `verification.reinstate.decide` | `verification_reinstate` (đề xuất `verification.reinstate.request`, duyệt `verification.reinstate.decide`) | xác minh danh tính chờ duyệt, doanh nghiệp chờ duyệt, giải thưởng chờ duyệt | uid của thợ → S23.04 chi tiết |
| #165 Khiếu nại và hộp thư (`staff-disputes-support.md`) | `dispute.view`, `dispute.view_summary`, `dispute.resolve`, `dispute.chat_view`, `support.view_help`, `support.reply`, `support.assign`, `support.close`, `support.note`, `support.view_dispute` (bảng vai trò trong spec; xem ruling 7) | `dispute_resolve` (đề xuất và duyệt đều `dispute.resolve`; hai người khi `refundAmount ≥ twoPersonThreshold`) | khiếu nại đang mở (đỏ khi quá 72 giờ), hội thoại chờ trả lời (đỏ khi quá 12 giờ) | `#K7Q2` (4 ký tự cuối id), id khiếu nại, hoặc id booking có khiếu nại |
| #166 Kiểm duyệt (`staff-moderation.md`) | admin + support: `report.view`, `report.decide`, `report.context_view`, `account.suspend`, `recruit_flag.view`, `recruit_flag.decide`; admin: `account.ban`, `account.unsuspend`; admin + support: `account.ban.decide` | `account_ban` (hai người khi chủ tài khoản là thợ có booking chưa xong hoặc tiền đang giữ) | báo cáo chờ xử lý, cờ tuyển dụng | theo spec ticket |
| #168 Cấu hình và nội dung (`staff-config-content.md`) | admin: `event.view_all`, `event.manage_any`, `config.view`, `config.change`, `config.decide`; admin + sales: `event.create`, `event.manage_own`, `promo.view`, `promo.send`; admin + support: `studio_stats.view` | `event_cancel` (duyệt `event.manage_any`), `config_change` (duyệt `config.decide`) | theo spec ticket | theo spec ticket |
| #167, #169 Studio web (`studio-web-operations.md`, `studio-web-business.md`) | không (chủ studio không dùng `StaffAction`; quyền theo studio, spec #167) | không | thẻ việc cần làm của S28.01 nằm ở `/studio`, không ở S23.09 | không |

Khi một ticket thêm `kind` vào `APPROVAL_KINDS`, các hàm `approvableKinds`/`requestableKinds` làm mục "Chờ duyệt" và thẻ đếm tự đúng: viết `ApprovalKindSpec` đủ `requestAction`, `approveAction`, `stillValid` (chỉ đọc) và `run` (tự ghi audit của thao tác gốc, actor là người duyệt, `diff` nêu cả hai uid). Danh sách bên trên là bản tại 2026-11-14; nguồn sự thật là spec của từng ticket.

## Lưu ý triển khai App Hosting (chưa quyết, trước khi bật Blaze)

Đường deploy `deploy-dashboard` chưa chạy được như cấu hình: firebase-tools 15.34.2 nén `options.projectRoot` = thư mục chứa file `--config`, tức `firebase/`, rồi App Hosting tìm `rootDir` (`apps/dashboard`) trong gói đó. `apps/dashboard` và `packages/domain` (import qua đường dẫn tsconfig, ngoài thư mục app) không nằm trong gói. Cần một trong hai: `firebase.json` ở gốc repo cho lần deploy này (gói là cả repo, `rootDir` `apps/dashboard`, có domain), hoặc backend App Hosting nối thẳng GitHub và bỏ job. Giữ giá trị như plan; vô hại khi Blaze còn tắt. Thêm: `apphosting.yaml` mới có `runConfig`, biến môi trường ghi dạng chú thích (giá trị ở console; `NEXT_PUBLIC_*` cũng phải có lúc build); một push chỉ đụng `apps/dashboard/**` chạy lại cả workflow `firebase-deploy` vì danh sách `paths` dùng chung.

## Còn mở (hoãn đến review cuối hoặc ticket sau)

- Dòng "Tải thêm" mất khi làm mới 30 giây (chỉ khi hơn 50 yêu cầu chờ).
- Hai lần render mỗi lần ghi (`revalidatePath` + `router.refresh()`).
- S23.11: bộ lọc chip so với ô chọn trong mock; S23.15: phụ đề so với mock; S23.10: avatar ở các hàng.
- Kiểm chỉ mục `in` + `__name__` của truy vấn duyệt trên emulator thật (CI hoặc review cuối).
- Test: tên test cũ "non-admin" ở `payout_use_cases.test.ts`; CLI chi trả chưa có ca finance; `guardEnv` thiếu ca (credentials với host emulator, host Auth không local, thiếu `GCLOUD_PROJECT`); `staff list` chỉ đọc `staff_members` nên lệch chỉ ở claim không thấy được; chưa có `scripts/staff-local.sh`; test thu hồi phiên phụ thuộc thứ tự; khoá duyệt "ý định sau thắng" nếu một giao dịch đặt pending mới rồi expired cũ trên cùng thực thể (chưa có chỗ dùng).
- Tăng cường truy cập: roving tabindex cho `DataTable`; `ScreenCode` chỉ nghe `popstate`; ngăn kéo studio chỉ ẩn bằng CSS (chưa test).
- Playwright: spec `mfa.spec` bỏ qua khi `MFA_DEV_BYPASS=1` (CI luôn bật bypass), nên đường "gọi callable không có TOTP" chỉ kiểm tay; e2e chưa chạy trên runner GitHub.
- Sau khi cấp vai trò mới, phiên cũ của người được cấp bị thu hồi và họ phải đăng nhập lại: hành vi có chủ đích.

## Chữ tiếng Việt mới không có chữ trong mock (chủ sản phẩm xem lại)

Task 9 tự viết, ở booking-be `apps/dashboard/src/messages/vi.ts`:

| Khoá | Chữ |
|---|---|
| `s23_08.wrong_password` | Email hoặc mật khẩu không đúng. |
| `s23_08.too_many` (ánh xạ từ `auth/too-many-requests`) | Thử sai quá nhiều lần. Đợi một lát rồi thử lại. |
| `s23_08.account_exists` | Email này đã đăng nhập bằng cách khác. Dùng lại cách đó. |
| `s23_08.failed` | Không đăng nhập được. Thử lại. |
| `s23_08.reverify` | Đăng nhập lại để nhập mã xác thực. |
| `s23_08.not_allowed_lead` | Dashboard dành cho staff và chủ studio. |
| `s23_08.choose_title` | Bạn muốn vào trang nào? |
| `s23_08.enrol_failed` | Không tạo được mã bí mật. Thử lại. |
| `s23_08.copied` | Đã sao chép |
| `idle.title`, `idle.body`, `idle.stay` | Bạn còn ở đây không? · Đã 30 phút không thao tác. Tự đăng xuất sau {n} giây. · Tiếp tục làm việc |
| `forbidden.title`, `forbidden.lead`, `forbidden.home` | Không có quyền truy cập · Tài khoản của bạn không được mở trang này. · Về trang chính |

Ghi chú: trang 403 là chuyển hướng tới `/403` (HTTP 307 rồi 200), vì `forbidden()` của Next 16.4 còn sau `experimental.authInterrupts`; bật cờ đó nếu cần mã 403 thật. Trang 403 dùng chung stylesheet của trang đăng nhập.
