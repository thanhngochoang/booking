# Handover ledger — #163 phần A: nền tảng tiền và màn Chi trả (S23.02)

Plan: `docs/superpowers/plans/2026-11-15-163-staff-money.md`. Spec: `docs/superpowers/specs/screens/staff-money.md`. Dashboard: `docs/superpowers/specs/2026-10-08-dashboard-web-design.md` (§5.4). Mock: `docs/design/dashboard-mock.html#S23.02`. Ledger trước: `ledger-162-dashboard-foundation.md`.

#163 chia ba đơn vị, cùng tên nhánh `plan/163-staff-money` ở hai repo. Phần A (file này, task A1–A6) mang mọi thay đổi dùng chung; phần B (#342) và phần C (#343) dựng tiếp trên đó.

- **booking-be** (code: `packages/domain`, `firebase/functions`, `firebase/firestore.*`, `apps/dashboard`), merge trước. Tên trong file này lấy từ code ở đó.
- **booking**: PR này, chỉ tài liệu (data model, trạng thái màn, spec dashboard §5.4, file này).

## Hiện có gì

- **Quyền** (`packages/domain/src/staff_permissions.ts`): `payout.manage` đã bỏ; 16 `StaffAction` tiền, đều admin và finance: `payout.view` · `payout.approve` · `payout.hold` · `payout.resume` · `payout.execute` · `transfer.view` · `transfer.assign` · `transfer.refund` · `transfer.dismiss` · `refund.view` · `refund.retry` · `refund.mark_manual` · `instant.staff_cancel` · `tax.view` · `tax.export` · `money_approval.decide`.
- **Ngưỡng hai người** (`money_controls.ts`): `MoneyControls`, `DEFAULT_MONEY_CONTROLS` (10.000.000₫), `moneyControlsOf`, `requiresTwoPeople`, `MoneyControlsReader`, `MoneyResult`, `runOrRequest`. Adapter Firestore `FirestoreMoneyControlsReader` đọc `platform_config/money` (rules chặn client).
- **Duyệt hai người** (`staff_approvals.ts`): `ApprovalKindSpec` có `stillValid` tuỳ chọn và đúng một trong `run` / `execute`; `ApprovalRef`, `approvalDiffOf`, `APPROVAL_CLAIM_SECONDS = 120`, `STALE_CODES`; `StaffApproval.claimedBy`/`claimedAt`; `decideApproval` chạy nhận việc → `execute` → đóng (D2); `payout_approve` có trong `APPROVAL_KINDS`.
- **Audit** (`audit.ts`): cổng `AuditLog` (ghi sau commit cho thao tác qua kho có sẵn, D3). Mã lỗi mới `already_paid` ở bốn chỗ (domain `errors.ts`, Functions `TRANSPORT_CODE`, root `HTTP_STATUS`, `errors.test.ts`) và `error.already_paid` trong `vi.ts`.
- **Chi trả** (`payout_use_cases.ts`): `PayoutTx extends AuditWriter`; `requirePayoutStaff`; `approvePayout(…, reason, ref?)`, `holdPayout` (nhận `pending` và `needs_approval`), `resumePayout(…, reason)`, `executePayout`, `staffExecutePayout` (D4), `requestOrApprovePayout`, `payoutApprovalKinds`; `Payout.rerunAt`/`rerunBy`.
- **Callable** (`firebase/functions/src/callables/money.ts`): `approvePayout`, `holdPayout`, `resumePayout`, `executePayout` (trả `{status: 'done', payoutIds}`; `payoutIds` rỗng là hợp lệ). `decideStaffApproval` và `cancelStaffApproval` chuyển sang `PAYMENT_CALLABLE_OPTIONS` (cần secret khoá tài khoản). Dựng phụ thuộc: `infra/live_money.ts` (`liveMoneyDeps`, `approvalKindsFor`), `live_staff.ts` (`liveApprovalDeps().kinds` gộp `payoutApprovalKinds`).
- **Firestore**: chỉ mục `payouts (status, processingAt)`, `(status, paidAt DESC)`, `(accountId, createdAt DESC)` và `staff_approvals (status, kind, expiresAt)`; rules đóng `platform_config/{doc}`. Bản quan hệ ở `specs/data-model/relational-schema.md` §2.4, §2.7, §3.
- **CLI** `npm run payouts` đi qua `requestOrApprovePayout` (từ ngưỡng thì in `awaiting second approval <approvalId>`); `--reason` bắt buộc cho approve/hold/resume/execute (hold không còn nhận lý do theo vị trí); mỗi lệnh kiểm hành động riêng.
- **Seed**: `seed-payout-an-approve` (`needs_approval`, net 3.441.000₫, `firstPayout`), `seed-payout-bai-da-big` (`needs_approval`, net 18.400.000₫, organizer), `seed-payout-an-failed` (`failed`, 2 ngày tuổi). Mục của chúng nêu payment không có trong seed.
- **Dashboard** (`apps/dashboard`):
  - Component và đọc: `components/Tabs.tsx` (D12), `MoneyReader` (`server/read/money.ts`, `controls()`), mã hoá con trỏ `encodeCursor`/`decodeCursor` (`server/read/firestore/cursor.ts`), `count()`/`doc()` trên `QueryLike`/`DbLike`, `QueueCardSpec` (`QUEUE_CARDS`: `payouts_waiting`, `money_approvals`), `entityHref`/`entityLabel` (`lib/labels.ts`), `NAV_ID_OF_CARD` (`app/(staff)/staff/layout.tsx`), nhãn `approval.kind.*`.
  - Màn S23.02 `/staff/payouts?tab=…&id=…`: reader `server/read/payouts.ts`, DTO ở `lib/dto.ts`, `lib/payout-tabs.ts`, thư mục `app/(staff)/staff/payouts/` (page, `PayoutsScreen.client`, actions).
  - Menu "Chi trả" cho admin và finance; số chờ ở thanh bên cùng nguồn với thẻ S23.09.
- **Playwright** `apps/dashboard/e2e/payouts.spec.ts` (serial, không retry): finance duyệt khoản 3.441.000₫ → finance gửi khoản 18.400.000₫ sang duyệt lần hai → finance ở S23.15 chỉ thấy "Huỷ yêu cầu" → admin duyệt → sales gõ `/staff/payouts` nhận 403. Chạy một lần mỗi lần seed lại emulator (spec dùng hết dữ liệu seed). `roles.spec.ts` đã cập nhật menu (finance: Tổng quan, Chờ duyệt, Chi trả); `menuLabels` bỏ chữ của huy hiệu số.

## Rulings (mỗi dòng một quyết định)

Quyết định của plan:

1. **D1 · Ba đơn vị.** Các màn độc lập ngoài nền tiền dùng chung, nên làm thành ba đơn vị; phần A mang mọi thay đổi dùng chung.
2. **D2 · Thao tác tiền duyệt xong chạy sau giao dịch duyệt, dưới dấu nhận việc.** `ApprovalKindSpec.execute(approver, params, ref)`; ba bước nhận việc 120 giây → chạy → đóng (`approved`, hoặc `rejected` ghi chú `stale` khi mã trong `STALE_CODES`); lỗi khác nhả dấu nhận việc và dòng vẫn `pending`. Trạng thái tiền luôn là sự thật.
3. **D3 · Audit.** Kho viết mới (chi trả, duyệt chuyển khoản, thao tác hoàn) ghi audit trong cùng giao dịch; thao tác qua kho có sẵn ghi ngay sau commit qua cổng `AuditLog`, lỗi ghi được log mức error kèm id và callable vẫn trả kết quả; đối tượng tự mang người quyết (`review.decidedBy`, `manualBy`, ...).
4. **D4 · Sửa chi trả theo spec.** `holdPayout` nhận `pending` và `needs_approval`, không nhận `processing`; "Chạy lại" lô `failed` là `staffExecutePayout` (đánh dấu `rerunAt`/`rerunBy` → `createPayouts` → gửi từng lô `pending`), lô `pending`/`processing` thì gửi lại cùng id; tab Thất bại ẩn lô có `rerunAt`.
5. **D5 · Quyền.** `payout.manage` bị thay bằng 16 hành động của spec §8; CLI dùng hành động riêng từng lệnh.
6. **D6 · Không có kho khoá idempotency.** Callable nhận và bỏ qua `idempotencyKey`; máy trạng thái của đối tượng làm lần lặp thành `conflict`, `DecisionDialog` đã khoá sau lần xác nhận đầu (ruling 10 của #162).
7. **D11 · Điều hướng.** Nhóm tiền có Chi trả, Chưa khớp, Hoàn tiền, Thuế; "Chờ duyệt" giữ là mục duyệt duy nhất từ #162 (dùng chung với #164), không thêm "Duyệt lần hai"; số ở thanh bên lấy từ cùng reader với thẻ S23.09.
8. **D12 · Tab là URL.** `?tab=<id>` đọc ở server; `Tabs` render link với `role="tablist"`; đổi tab là điều hướng, mỗi tab một truy vấn reader và sống qua làm mới.

Dòng `Ruling` trong ledger SDD:

9. **Ruling 1 (pre-flight):** A1 cũng chạy test đơn vị `apps/dashboard` và chỉ sửa kỳ vọng đổi vì `APPROVAL_KINDS` nay có `payout_approve` (finance mở được Chờ duyệt), để mỗi task xanh; nếu sai thì A4 sửa lại các test đó.
10. **Ruling 2 (pre-flight):** A1 thay `payout.manage` bằng `payout.execute` trong `firebase/functions/tools/payouts.ts` như bước tạm để Functions typecheck xanh; A2/A3 chia lại theo từng lệnh.
11. **Ruling 3 (pre-flight):** A2 chịu mọi gợn biên dịch do đổi chữ ký của mình (mixin `bufferedAuditWriter` trong `FirestorePayoutStore.runTransaction`, các chỗ gọi của CLI, cờ `--reason` bắt buộc); A3 giữ đường ngưỡng (`requestOrApprovePayout`) trong CLI, callable, rules, chỉ mục, seed; mỗi commit đều typecheck.
12. **Ruling (A5, toast chạy lại rỗng):** kết quả `executePayout` có `payoutIds` rỗng hiện toast thông tin "Khoản này sẽ được gộp vào lần chi tự động kế tiếp" thay vì "Đã chạy lại" (`[]` nghĩa là lần chạy hằng ngày sẽ gộp lại, hoặc tài khoản chưa active); nếu sai thì sửa một chuỗi.
13. **Ruling (A5, chữ hộp duyệt):** hộp "Duyệt chi" theo mock (tiêu đề "Chi {amount} cho {name}?", ngân hàng và chủ tài khoản ở phần tóm tắt) thay cho tiêu đề của plan/spec (có "về {bank} •••• {last4}"; CLAUDE.md: mock thắng về chữ); nếu sai thì một chuỗi.

Quyết định áp dụng của A1 (báo cáo A1):

14. Yêu cầu quá hạn thì đóng `expired`, không `execute`; từ chối khi dấu nhận việc còn mới là `conflict` (với mọi người nhận việc); cho phép tiếp quản dấu nhận việc cũ, vẫn kiểm `same_person`; `approval.decide` chỉ ghi ở bước đóng; `stillValid` sai ở bước nhận việc đóng dòng `rejected`/`stale`. Dấu nhận việc còn mới cũng chặn chính người nhận việc duyệt hoặc từ chối lại ngay (coi là `conflict`).

## Phần B và C cần biết

Dùng lại, đừng viết lại:

- **`runOrRequest`** (`money_controls.ts`): `runOrRequest(deps: {approvals, controls}, caller, req, now)`: `req` là đầu vào `requestApproval` kèm `amount`, `now` là thao tác chạy ngay; dưới ngưỡng thì chạy `now` và trả `{status: 'done'}`, từ ngưỡng thì mở yêu cầu và trả `{status: 'awaiting_second_approval', approvalId}` (`MoneyResult`). Ngưỡng đọc qua `MoneyControlsReader.get()`.
- **`ApprovalKindSpec.execute`**: `kind` mới của #342/#343 (`transfer_assign`, `transfer_refund`, `transfer_dismiss`, `refund_manual`, `instant_staff_cancel`) đều đi kho riêng nên dùng `execute`, không dùng `run`. `execute` phải dựa vào trạng thái đối tượng để chạy lần hai là `conflict`/`not_eligible`/`already_paid`/`not_found` (các mã trong `STALE_CODES`); mã khác làm dòng vẫn `pending`. Đăng ký ở `liveApprovalDeps().kinds` và `approvalKindsFor` (`live_money.ts`) rồi thêm `approval.kind.<kind>` ở `vi.ts`. Dùng `approvalDiffOf(ref, uid)` để audit nêu cả hai uid.
- **`AuditLog`** (`audit.ts`): cổng ghi audit sau commit cho thao tác qua kho có sẵn (gán chuyển khoản, đánh dấu hoàn thủ công, staff huỷ yêu cầu chụp ngay); kho viết mới thì trộn `AuditWriter` vào `Tx` (xem `bufferedAuditWriter` ở `infra/payout_firestore.ts`).
- **`MoneyResult`, `liveMoneyDeps`** (`infra/live_money.ts`): dựng phụ thuộc cho callable tiền; `money.ts` ở `callables/` là mẫu `run(name, gate(request, deps, '<action>'))` + `parseStaffInput`.
- **`Tabs`** (`components/Tabs.tsx`): link `role="tab"` trong `role="tablist"`, `aria-current="page"` cho tab đang chọn; tab là query `?tab=`, trang đọc tab ở server và truyền cho màn.
- **Con trỏ** (`encodeCursor`/`decodeCursor`): con trỏ opaque `(giá trị sắp xếp, id)`; reader quét tối đa 5 lô sau con trỏ cho đủ `pageSize` hàng hiện được (xem `server/read/firestore/payouts.ts`), `next` là tài liệu quét cuối khi còn nữa. Màn giữ cờ `loaded` để `next` lấy từ phản hồi cuối.
- **`QueueCardSpec`** (`server/read/firestore/overview.ts`, `QUEUE_CARDS`): mỗi thẻ có `count`, `late`, `oldest`; `count` nhận thêm `role` và có thể trả `null` (bỏ thẻ). Thêm thẻ của #342/#343 (chuyển khoản chưa khớp, hoàn tiền lỗi) ở đây; thẻ lỗi hiện lỗi trong thẻ, không kéo thẻ khác; số đếm chỉ có huy hiệu khi > 0. `queues` được cache theo vai trò (`cache()`).
- **`entityHref`/`entityLabel`** (`lib/labels.ts`): trả route chi tiết hoặc `null`, dùng ở S23.15 để link sang đối tượng; thêm `payout` → `/staff/payouts?id=`; #342/#343 thêm `transfer`, `refund`.
- **`NAV_ID_OF_CARD`** (`layout.tsx`, không export vì Next cấm export thêm từ layout): ánh xạ thẻ → mục menu cho huy hiệu thanh bên; thêm mục của #342/#343 ở đây và ở `STAFF_NAV` (`nav.ts`).
- **`MoneyReader.controls()`**: `twoPersonThreshold` cho hộp xác nhận ("Gửi duyệt lần hai" từ ngưỡng).
- **`QueueLayout`** có `initialOpenId` (liên kết sâu `?id=`); `DetailPane`, `DecisionDialog` (hộp lý do 5–500) như #162.
- **Chỉ mục, rules, seed**: mọi truy vấn mới cần chỉ mục khớp trong `firestore.indexes.json` (test chỉ mục kiểm); truy vấn đếm chỉ có điều kiện bằng thì không cần chỉ mục ghép, còn có `orderBy` trên trường khoảng thì cần. Seed của #342/#343 theo mẫu `queued(...)` trong `seed/fixtures.ts`.
- **Còn thiếu cho phần B/C**: `payout_approve` mới là `kind` duy nhất trong `payoutApprovalKinds`; các `kind` khác ở spec §2 chưa có. `already_paid` đã có sẵn cho gán chuyển khoản.

## Còn mở (hoãn đến review cuối hoặc ticket sau)

Từ review của A1:

- `staff_approvals.test`: ca "execute ném lỗi khác" chỉ là vòng một phần tử; thêm kiểm dấu nhận việc về `null` sau lần từ chối đầu.
- Nhả dấu nhận việc lỗi thì lỗi nhả thay lỗi gốc: bọc bước nhả trong try/catch và ném lại lỗi gốc.
- `approvals.test` (dashboard): test đầu "an empty registry" nay kiểm registry production; đổi tên hoặc tách.
- `staff_approvals.test` import trùng `../src/staff_approvals.js`.
- Chú thích ở bước đóng về mép tiếp quản/stale (tiền đã đi nhưng dòng `rejected`/stale, đóng bị `conflict`).

Từ review của A2:

- JSDoc `staffExecutePayout`: dấu `rerunAt` được ghi trước `createPayouts`; lần chạy hằng ngày là đường khôi phục.
- Chưa test đường `failed` khi lô mới là `needs_approval`/`on_hold` (trả về, không gửi).
- `payout_approve.stillValid` đọc trong giao dịch riêng (cần chú thích).
- Audit gửi lại `processing` có `diff` vô nghĩa `['processing','processing']`.

Từ review của A3:

- Từ chối khi không có TOTP chỉ test cho approve; tham số hoá qua `HANDLERS`.
- `liveApprovalDeps` đọc `PAYOUT_ACCOUNT_KEY` sớm, ngoài `run` (cấu hình sai ra `internal` không gắn thẻ).
- CLI approve đọc lại payout chỉ để in trạng thái.
- Payout seed nêu payment không có trong seed: xem log emulator một lần xem `onPayoutWritten`/`refreshEarnings` có ồn không (việc của A6; **chưa làm được**, xem dưới).
- Test tích hợp `test/integration/money.test.ts` và rules test chưa chạy trong sandbox; CI chạy.

Từ review của A4:

- `Tabs` là link `role=tab` không có `tabpanel` và phím mũi tên (D12); `aria-current` đã thêm.
- Thẻ lỗi phát lại `role=alert` mỗi lần làm mới.

Từ review của A5:

- Chi tiết nhấp nháy về `DetailEmpty` sau thao tác với hàng `?id=` ngoài trang.
- Chi phí đọc: `awaiting()` đọc tới 500 yêu cầu mỗi trang và mỗi lần mở chi tiết; `?id=` chạy tra cứu ngữ cảnh hai lần.
- Tài liệu hỏng có trường thứ tự `null` làm phân trang dừng sớm (không quay vòng).
- Payout `pending` mở bằng `?id=` không có chân (D4 chỉ cho "Tạm giữ…" ở tab Chờ duyệt).
- Số đếm tab Thất bại không trừ được lô có `rerunAt` (`count()` không lọc được), nên huy hiệu có thể lớn hơn số hàng hiện.

Từ A6:

- Playwright `payouts.spec.ts` **chưa chạy được ở máy này** (không có Java cho emulator Firestore); controller hoặc CI chạy. Lần chạy đầu cần xem log emulator của seed payout.
- `Payout.processingAt` có trong code từ trước nhưng docs chưa nêu; đã thêm vào `domain-model.md` và `relational-schema.md` cùng đợt này.

## Chữ tiếng Việt mới không có chữ trong mock (chủ sản phẩm xem lại)

Ở booking-be `apps/dashboard/src/messages/vi.ts`, các khoá `s23_02.*` trừ những chữ đã có trong mock hoặc brief. Từ báo cáo A5:

| Nhóm | Chữ |
|---|---|
| Trạng thái trống từng tab | Không có khoản chi nào chờ duyệt · Không có khoản chi nào đang tạm giữ · Không có khoản chi thất bại trong 30 ngày qua · Không có khoản chi nào xử lý quá 2 giờ · Chưa có khoản chi nào trong 30 ngày qua |
| Loại người nhận, số khoản | `ban tổ chức` · `{n} khoản` |
| Hộp Tạm giữ | Tạm giữ khoản chi {amount} cho {name}? · Khoản chi dừng lại và không đi ở lần chạy tự động cho đến khi tiếp tục chi. |
| Hộp Tiếp tục chi | Tiếp tục chi {amount} cho {name}? · Khoản chi được mở lại. Nếu tài khoản chưa có lần chi nào, khoản này quay về Chờ duyệt. |
| Hộp Chạy lại | Chạy lại khoản chi {amount} cho {name}? · Hệ thống gửi lại lệnh chi ngay, không đợi lần chạy tự động 10:00. |
| Chi tiết | Tài khoản · Tên chủ tài khoản · Khớp / Chờ đối chiếu / Staff đã xác nhận · Họ tên đã xác minh · Chi được từ · Còn khoá 72 giờ, chi được từ {time} · Các khoản · Khoản · Gộp · Hoa hồng · Thuế {rate}% · Tổng · Lịch sử chi · Chưa có lần chi nào · Lý do tạm giữ · Hệ thống tạm giữ sau nhiều lần chi thất bại · Lỗi lần chạy trước |
| Trạng thái, tải | nhãn trạng thái chi trả · Đang tải chi tiết… · Không tải được chi tiết khoản chi · Không tải được danh sách chi trả · Trạng thái chi trả (nhãn `tablist`) |
| Toast chạy lại rỗng | Khoản này sẽ được gộp vào lần chi tự động kế tiếp |
| `error.not_eligible` (chữ chung) | Chưa làm được: đối tượng chưa đủ điều kiện. |

Ghi chú: báo cáo A1–A4 không liệt kê chữ mới; các nhãn A4 thêm (`approval.kind.payout_approve` "Duyệt lần chi đầu", `queue.card_error`, tên thẻ và mục menu "Chi trả") và `error.already_paid` (A1) cũng không có trong mock, chủ sản phẩm xem lại cùng bảng trên.
