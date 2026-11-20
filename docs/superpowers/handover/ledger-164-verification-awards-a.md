# Handover ledger — #164 phần A: duyệt giải thưởng (S23.07), NAG chờ xác minh (V1)

Plan: `docs/superpowers/plans/2026-11-17-164-staff-verification-awards.md` (phần A, task A1–A5). Spec: `docs/superpowers/specs/screens/staff-verification-awards.md` (§3, §4). Dashboard: `docs/superpowers/specs/2026-10-08-dashboard-web-design.md`. Mock: `docs/design/dashboard-mock.html` (#S23.07), `docs/design/ui-mock.html` (S25.01).

Phần A (#164) cùng tên nhánh `plan/164-s23-duyet-xac-minh-giai-thuong` ở hai repo, dựng trên #163 đã merge.

- **booking-be** (`packages/domain`, `firebase/functions`, `apps/dashboard`), merge trước. Tên trong file này lấy từ code ở đó.
- **booking**: PR này, gồm app (S25.01, A4), tài liệu và file này.

## Hiện có gì

- **A1 (domain)**: 5 `StaffAction` mới; `tierFor(current, approvedCount, verified)` và `TierState.verified`; `reviewAward(deps, caller: StaffCaller, raw)` (cổng `award.review`, `AwardTx.audit` ghi `audit_log` cùng giao dịch); `review_sla.ts` (`businessCutoff`, `awardWait`).
- **A2 (Functions)**: callable `reviewAward` qua `gate()`; `recomputeTierOnVerifiedChange` trong `triggers/photographer_write.ts`; `reviewVerification` và CLI `tools/verifications.ts` tính lại hạng khi xác minh danh tính đổi trạng thái; `KIND_ACTION` là `award.view` / `verification.view`; chỉ mục `awards (status, updatedAt)` và `(status, reviewedAt asc/desc)`; seed: Giang (chưa xác minh, 2 giải đã duyệt, `seed-award-giang-3` chờ), Bình (`seed-award-binh-1` chờ, `-2` cần bổ sung, `-3` từ chối), Dũng (đã xác minh, 3 giải).
- **A3 (dashboard)**: `/staff/awards?tab=&id=` (`app/(staff)/staff/awards/`), reader `server/read/awards.ts`, `requestSensitiveFileUrl`, `DecisionDialog` `reasonMode: 'optional'`, `lib/nav-badges.ts`, thẻ `awards_pending`, `lib/nag.ts`.
- **A4 (app)**: `AwardTier.verified`; thẻ hạng S25.01 hiện "Xác minh ngay" cho thợ đủ 3 giải chưa xác minh.
- **A5**: `apps/dashboard/e2e/awards.spec.ts` (4 ca, tuần tự); `team.spec.ts` sửa menu support thành `[Tổng quan, Giải thưởng]`. Playwright chưa chạy trong sandbox; `providerType` kiểm qua giao diện (dòng phụ "NAG · n giải" so với "n giải đã duyệt" ở tab Đã duyệt), vì không spec nào đọc emulator trực tiếp.
- **Tài liệu**: V1 ở spec 10-05 §2.3, `TierState` và `tierFor` ở `domain-model.md`, §3 `staff-verification-awards.md`, ô trạng thái S23.07.

## Rulings

Quyết định của plan:

1. **D1 · Xây trên Firebase như #163.** Ghi chú 2026-11-15 nói các màn còn lại nên dựng trên API Node.js + PostgreSQL, nhưng #163 đã làm trên callable Firebase và chưa có spec Phase 2 (#170). Nếu sai: reader và callable của hai màn chuyển sang API cùng cụm tiền và nội dung (#183).
2. **D2 · Hai đơn vị.** Phần A chứa mọi thay đổi dùng chung (các `StaffAction`, V1, siết duyệt giải) cộng S23.07; phần B (#349) chỉ chứa phần riêng S23.04.
3. **D3 · V1 một quy tắc, áp bằng tính lại.** `tierFor(current, approvedCount, verified)`; `recomputeTier` đọc `verified` qua `TierState`. Tính lại sau duyệt giải, sau mỗi thay đổi xác minh làm `verified` đổi (sau commit, lặng lẽ) và bằng `onPhotographerWrite` khi `verified` đổi (lưới an toàn). Spec muốn cùng giao dịch; tính lại idempotent nên cửa hàng xác minh không có cổng giải. Nếu sai: vài giây thợ vừa xác minh còn hiện `individual`.
4. **D4 · Thợ NAG chưa xác minh mất hạng ở lần tính lại tiếp theo.** Là quy tắc V1; chưa có dữ liệu production. Seed: Dũng đã xác minh.
5. **D5 · Audit cạnh các collection audit cũ.** `reviewAward` giữ ghi `awardAudit` (CLI và app đọc) và ghi thêm `audit_log` cùng giao dịch qua `AuditWriter` trên cổng giao dịch.
6. **D6 · Người gọi.** `reviewAward(deps, caller: StaffCaller, raw)` kiểm bằng `assertStaffCaller` với `award.review` cho mọi hành động giải. CLI dựng `{uid: actor, role: 'admin', mfa: true}`.
7. **D11 · Thứ tự hàng đợi giải.** Chờ duyệt: `updatedAt` tăng (tính từ lúc vào `pending`, sửa sau "Cần bổ sung" tính lại); Cần bổ sung: `reviewedAt` tăng; Đã duyệt và Đã từ chối: `reviewedAt` giảm. Giải trễ có `updatedAt` cũ hơn `businessCutoff(now, 72)`.
8. **D12 · Menu và thẻ.** Nhóm "Hàng đợi" có Xác minh (`verified_user`) và Giải thưởng (`emoji_events`) trước Chờ duyệt như mock; S23.09 có ba thẻ `verifications_identity`, `verifications_business`, `awards_pending`; `navBadges` cộng các thẻ cùng mã menu.
9. **D14 · `DecisionDialog` có `reasonMode: 'optional'`.** Hộp duyệt giải dùng nó; lý do trống gửi đi là không có `note`.
10. **D15 · Tệp nhạy cảm.** `requestSensitiveFileUrl` là server action đầu tiên của dashboard cho `getSensitiveFileUrl`; `award_proof` kiểm `award.view`, `business_doc` kiểm `verification.view`; `KIND_ACTION` của callable chuyển sang cùng hai hành động `.view`. Tài liệu doanh nghiệp là JPEG nên `SecureFileViewer` (chỉ ảnh) đủ.

Ruling của controller (ledger SDD):

11. **Ruling 1:** A1 giữ mọi nơi gọi biên dịch được (Functions, CLI, API gốc đổi cơ học sang chữ ký mới) để cây luôn xanh; A2 thay kiểm tra của callable bằng `gate()`.
12. **Ruling 2:** hàng `APPROVAL_KINDS.verification_reinstate` chuyển từ A1 sang B1 cùng `execute` của nó; nếu thêm sớm, support có mục "Chờ duyệt" trống và request quyết định được nhưng không chạy được. Menu support phần A là `[Tổng quan, Giải thưởng]`.
13. **Ruling 3:** giải trễ khi `awardWait` > 72; `businessCutoff(now, 72)` là thời điểm muộn nhất còn đủ 72 giờ làm việc, nên số thẻ dùng khoảng chặt `updatedAt < businessCutoff(now, 72)` để thẻ và hàng khớp ở ranh giới.
14. **Ruling 4:** A4 (app) chạy song song với A2 vì khác repo, khác file; chỉ chung trường `photographers.verified` mà A1 đã định nghĩa.

Lệch có chấp nhận (báo cáo A3):

15. Chân hộp theo mock (Từ chối…, Cần bổ sung…, Duyệt), không theo thứ tự trong brief.
16. Tiêu đề bài dự thi là `caption` của bài (bài chỉ có `caption` và `imageUrls`, không có `title`); ảnh đầu đã vào `imageUrl` nhưng màn chưa hiển thị.
17. Màn tách `requestAwardProofUrl({entityId, file})` ở `awards/actions.ts` vì màn client không import được `src/server` (test thuần); màn bọc bằng `unwrap(withSessionRetry(...))`.
18. Ghi chú thu hồi giải là 5–500 ký tự như các hành động giải khác; 20 ký tự tối thiểu (spec §2.3) chỉ cho thu hồi xác minh, thuộc phần B. Ban đầu A3 đặt `minLength={20}`; đã sửa theo ruling của controller.
19. Ô "Chờ" chỉ đỏ với giải `pending` (cột có ở mọi tab nhưng "trễ" chỉ có nghĩa ở tab Chờ duyệt).

## Phần B (#349) cần biết

- Mục menu Xác minh và hai thẻ `verifications_identity`, `verifications_business` đang ẩn sau `NAV_HIDDEN`; B3 bỏ `NAV_HIDDEN` và dựng màn.
- Href thẻ doanh nghiệp `/staff/verifications?tab=business` là đoán của A3; B3 xác nhận hoặc đổi, kèm chỉ mục, test cho hai thẻ xác minh.
- Hàng `verification_reinstate` của `APPROVAL_KINDS` thuộc B1 (ruling 2), cùng `execute`; thêm nó sẽ cho support mục "Chờ duyệt" (`canApproveAny`).
- B2 viết lại callable và CLI xác minh: dùng lại `verifiedFlipped` trong `tools/verifications.ts` (hiện A2 tự so `approved` trước và sau).
- Thợ vừa được xác minh lại (duyệt, khôi phục) phải ra `artist` nếu đủ 3 giải: gọi tính lại hạng sau commit, như `recomputeAfterVerification` của A2.
- Seed: Giang chưa xác minh (duyệt giải thứ 3 vẫn `individual`; duyệt xác minh của cô sẽ lên `artist`); Dũng đã xác minh, có 3 giải, nhưng `e2e/awards.spec.ts` thu hồi `seed-award-dung-3`; cần reseed emulator trước khi chạy lại.

## Còn mở (hoãn)

Từ review A1:

- Comment trong test chưa gọn; `MemoryAwardStore` có `audit` và `auditLog` đặt tên lệch.

Từ review A2:

- `liveAwardDeps` dựng một phiên staff không dùng cho trigger và CLI.
- Chưa có test cho việc `handlePhotographerEvent` chuyển `awardDeps` xuống.
- Test tích hợp chỉ ngụ ý tính nguyên tử, chưa chứng minh.

Từ review A3 (cho đợt sửa cuối, chưa làm):

- Comment cũ "revoke ≥ 20" trong `awards/actions.ts` và tài liệu của `DecisionDialog` cho `'optional'`.
- Dòng "5/3" cho thợ NAG (đã là artist vẫn hiện `{n}/3`).
- Lịch sử giải `limit(50)` trước khi sắp xếp.
- Nhãn "Link" trùng lặp.
- Chi tiết đọc `photographers/{uid}` hai lần.
- Chưa có test ghim cổng của `requestSensitiveFileUrl`; link không phải https bị bỏ im lặng (miền chỉ lưu https).

Từ review A4:

- Test biến thể nút và thụt lề trong mock; `FakeAwardRepository.watchTier` mặc định vẫn suy ra `artist` ở n ≥ 3 mà không tính `verified` (test dùng `setTier`).

Chưa chạy: Playwright `awards.spec.ts` (cần emulator), test tích hợp Functions, `tokens:check`.

## Chữ tiếng Việt mới không có chữ trong mock

Dashboard (`apps/dashboard/src/messages/vi.ts`; chủ sản phẩm xem lại):

| Khoá | Chữ |
|---|---|
| `decision.reason_hint_optional` | Không bắt buộc, tối đa {max} ký tự |
| `s23_07.tabs_label` | Trạng thái giải thưởng |
| `s23_07.empty.needs_info` | Không có giải nào đang cần bổ sung |
| `s23_07.empty.approved` | Chưa có giải nào được duyệt |
| `s23_07.empty.rejected` | Chưa có giải nào bị từ chối |
| `s23_07.load_error` | Không tải được danh sách giải thưởng |
| `s23_07.detail_loading` | Đang tải chi tiết… |
| `s23_07.detail_error` | Không tải được chi tiết giải thưởng |
| `s23_07.detail_sub_no_category` | {result} · gửi {date} |
| `s23_07.proof_alt` | Minh chứng {n} của giải {competition} |
| `s23_07.no_proof` | Không có tệp minh chứng |
| `s23_07.link` | Link |
| `s23_07.work_post` | Bài dự thi |
| `s23_07.work_post_untitled` | Bài dự thi · ảnh công khai |
| `s23_07.nag` | NAG |
| `s23_07.nag_progress` | {n}/3 giải đã duyệt |
| `s23_07.nag_verified` | đã xác minh danh tính |
| `s23_07.nag_unverified` | chưa xác minh danh tính |
| `s23_07.review_note` | Ghi chú duyệt |
| `s23_07.reviewed` | Xử lý lần cuối |
| `s23_07.reviewed_by` | {time} · {name} |
| `s23_07.history` | Lịch sử |
| `s23_07.history_empty` | Chưa có lịch sử |
| `s23_07.approve_summary` | Giải được tính vào số giải đã duyệt của thợ. Ghi chú (nếu có) ghi vào nhật ký. |
| `s23_07.needs_info_summary` | Ghi chú này gửi cho thợ: nói rõ cần bổ sung gì. |
| `s23_07.reject_summary` | {competition} {year} của {name}. Ghi chú này gửi cho thợ. |
| `s23_07.revoke_summary` | {competition} {year} của {name} không còn được tính. |

Banner, tiêu đề hộp, toast, tab, cột và tên kết quả lấy từ mock hoặc brief; `waits_verification_hint` thay "3" bằng `{n}`.

App (S25.01, `app_flutter/lib/l10n/app_vi.arb`):

| Khoá | Chữ |
|---|---|
| `s2501EligibleVerify` | Đủ 3 giải · xác minh danh tính để lên Nhiếp ảnh gia |
| `s2501VerifyNow` | Xác minh ngay |
