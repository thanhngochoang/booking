# Handover ledger — #343 phần C: báo cáo thuế (S23.13)

Plan: `docs/superpowers/plans/2026-11-15-163-staff-money.md` (phần C, task C1–C3). Spec: `docs/superpowers/specs/screens/staff-money.md` (§7, §8). Dashboard: `docs/superpowers/specs/2026-10-08-dashboard-web-design.md`. Mock: `docs/design/dashboard-mock.html#S23.13`. Ledger trước: `ledger-163-money-a.md`, `ledger-163-money-b.md` (tên thật trong code thắng tên cũ trong plan).

Phần C (#343) cùng tên nhánh `plan/343-tax-report` ở hai repo, dựng trên phần A và B đã merge.

- **booking-be** (code: `packages/domain`, `firebase/functions`, `firebase/rules-test`, `apps/dashboard`), merge trước. Tên trong file này lấy từ code ở đó.
- **booking**: PR này, chỉ tài liệu (data model, trạng thái màn, file này).

## Đã làm gì

- **C1 (domain, `packages/domain/src/tax_report.ts`)**: `buildTaxReport` (thuần, gom khoản chi `paid` theo người nhận, nhận `now` tuỳ chọn), `taxCsv` (UTF-8 có BOM, CRLF), `periodBounds` (tháng giờ Việt Nam, đầu gồm, cuối loại), `TaxPayee`, cổng `IdentityNumberReader`; `IdentityRecord.idLast4?` ghi lúc xác minh và có ánh xạ trong `verification_firestore.ts`.
- **C2 (use case, callable, màn, seed)**:
  - `exportTaxReport(deps, caller, input, now)` là use case miền; thứ tự: cổng quyền, đầu vào, `identities === null` thì `not_eligible` (trước mọi lần đọc hay ghi), đọc, dựng CSV, lưu, audit, ký link. `taxPayeeOf` dùng chung cho adapter Functions và dashboard.
  - Callable `exportTaxReport` mỏng (`callables/money.ts`), `liveTaxExportDeps` và `liveTaxCallableDeps` ở `infra/live_money.ts`, adapter `infra/tax_export_firestore.ts` (khoản chi theo `(status, paidAt desc)`, người nhận, `FirestoreTaxIdentityReader`, `StorageTaxFiles`).
  - Dashboard `/staff/tax?period=YYYY-MM` (`app/(staff)/staff/tax/`: page, `TaxScreen.client`, actions, CSS), `lib/tax-period.ts`, reader `server/read/tax.ts` và `firestore/tax.ts`, mục menu Thuế (`tax.view`), `entityHref('tax_report')`.
  - Seed: `users/{AN}/private/identity` có `idNumberEnc` (kho dev, số thử `SEED_AN_ID_NUMBER`) và `idLast4` 4821.
  - 12 nhãn `audit.action.*` cho thao tác tiền (khoản "Còn mở" của ledger B).
- **C3**: `apps/dashboard/e2e/tax.spec.ts`; sửa `aria-label` của chip tháng để tên truy cập có tháng đang chọn ("Chọn tháng: Tháng 9/2026").
- **Tài liệu (repo này)**: `IdentityRecord.idLast4?` (`domain-model.md`), cột `id_last4` (`relational-schema.md`), S23.13 "✅ đã làm (#343)" và §8 (`staff-money.md`), ô trạng thái S23.13 ở `2026-10-01-remaining-screens.md`.

## Rulings

Quyết định của plan:

1. **D10 · Xuất thuế.**
   - Số định danh đầy đủ chỉ tồn tại dạng mã hoá (`users/{uid}/private/identity.idNumberEnc`); chỗ giải mã duy nhất là kho dev vì kho KMS chưa làm, nên `exportTaxReport` trả `not_eligible` ở nơi kho dev không được phép, như các callable danh tính.
   - 4 số cuối trên màn lấy từ `idLast4` mới trên bản ghi định danh (thiếu thì "—"); studio và tổ chức lấy từ `verifications/{uid}.business.taxCode`.
   - Tệp CSV ở `exports/tax/{period}/{ulid}.csv`; `pruneDataExports` đã xoá mọi thứ dưới `exports/` sau `EXPORT_TTL_DAYS = 7` nên không thêm job.
   - Callable tự trả URL ký; không thêm `kind` `tax_export` cho `getSensitiveFileUrl` (không màn nào tải lại tệp).
   - GTGT và TNCN tách từ `taxWithheld` đã chụp theo `DEFAULT_PAYOUT_POLICY.individualTaxBp` (500:200); TNCN nhận phần dư làm tròn.

Dòng `Ruling` trong ledger SDD (controller):

2. **Ruling 1:** `exportTaxReport(deps, caller, input, now)` là use case miền trong `tax_report.ts`, viết ở C2 (cổng: đọc khoản chi theo kỳ, đọc người nhận, `IdentityNumberReader | null`, kho tệp, bộ ký, `AuditLog`); `null` thì `not_eligible` (D10); callable mỏng. Lý do: luật nằm ở miền theo kiến trúc plan; nếu sai thì chuyển code.
3. **Ruling 2:** `TaxPayee.kind` là loại người nhận (`providerType`, mặc định `individual`; `organizer` khi không có loại nhưng có business đã duyệt); VAT/PIT lấy từ snapshot từng khoản chi (`taxRateBp`, `taxWithheld`) nên người nhận có khoản chi hỗn hợp vẫn đúng; sai nhãn chỉ sai chữ. **C2 sửa:** loại đọc từ `photographers/{uid}.providerType` chứ không phải `users/{uid}` (code, reader khoản chi và seed đều dùng `photographers`; tên thật thắng).
4. **Ruling 3:** seed thêm `idNumberEnc` (kho dev, số thử) và `idLast4` cho danh tính của An để Playwright có hàng thật và CSV có số đầy đủ trên emulator.
5. **Ruling 4:** C2 thêm nhãn tiếng Việt `audit.action.*` cho mọi thao tác tiền (`payout.*`, `transfer.*`, `refund.*`, `instant.staff_cancel`, `tax.export`), khoản "Còn mở" của ledger B.
6. **Ruling 5:** studio và tổ chức hiện `MST •••• {4 số}` từ `business.taxCode`, cá nhân `•••• {4 số}` từ `idLast4`; thiếu thì "—". C2 ban đầu cho studio chưa có business dùng 4 số CCCD gắn nhãn MST; review bắt lỗi, sửa ở 125a33a: `taxPayeeOf` trả `idLast4: null`, nên màn và tệp khớp nhau (cùng để trống).
7. **Ruling 6:** bộ chọn tháng của S23.13 theo mock (một chip `calendar_month` mở danh sách link 12 tháng, tỉ lệ nằm ở phụ đề) thay vì "link tháng" và dòng chú thích của brief; mock thắng về bố cục và chữ (CLAUDE.md). Nếu sai thì chỉ làm lại UI.
8. **Ruling 7 (hoãn):** hai bộ ánh xạ khoản chi (`payoutOf` của dashboard và `payoutFromFirestore` của Functions) chỉ lệch ở tài liệu hỏng; link ký ở production không có `response-disposition` (tệp tên `{ulid}.csv`); truy vấn khoản chi theo tháng không giới hạn (khối lượng dự kiến nhỏ).

Quyết định riêng của C2 (báo cáo C2):

9. Loại người nhận đọc từ `photographers/{uid}.providerType` (xem ruling 2).
10. Business chỉ tính khi `verifications/{uid}.business.status === 'approved'`; sau review: studio hay tổ chức không có mã số thuế đã duyệt thì "—" (ruling 5).
11. Chỉ mục `(status, paidAt desc)` của khoản chi đã có, nên `firestore.indexes.json` không đổi.
12. Callable dùng `CALLABLE_OPTIONS` (như `getSensitiveFileUrl`) chứ không phải `PAYMENT_CALLABLE_OPTIONS`, vì không cần khoá chi trả.
13. Audit ghi trước khi ký link (brief ghi ký trước): kết quả quan sát như nhau, và lỗi audit thì không có URL nào được tạo.
14. Tháng: mặc định tháng trước theo giờ Việt Nam; `?period=` sai dạng hoặc sau tháng hiện tại thì rơi về mặc định; menu 12 tháng gần nhất sau khi đổi sang chip.
15. Trình duyệt "đi tới URL" bằng thẻ `<a download>` bấm bằng code, để URL `data:` của emulator tải về và URL ký thật điều hướng; màn nhận prop `open` cho test.
16. Nhãn audit dùng "lần chi" cho khoản chi (khớp cột "Lần chi" của mock).

Quyết định của C3:

17. Playwright quan sát xuất tệp bằng sự kiện `download` (URL của download là URL `data:`), không dùng `waitForURL` vì trang không điều hướng; thêm đọc tệp tải về để kiểm số định danh đầy đủ của An chỉ có trong CSV. Tháng của khoản chi seed tính trong test bằng `now − 35 ngày` theo giờ Việt Nam, như seed.
18. `aria-label` của `<summary>` thành "Chọn tháng: {tháng}" thay vì bỏ hẳn, để giữ cả mục đích lẫn tháng đang chọn trong tên truy cập (review C2 fix 1, WCAG 2.5.3).

19. **Ruling 8 (review cuối):** ô số định danh chỉ có chữ số trong CSV thuế được ghi `="<chữ số>"` để Excel giữ số 0 đầu (CCCD luôn bắt đầu bằng 0); người đọc không phải Excel sẽ thấy lớp bọc `="…"`.

## Hiện có gì

- **Test**:
  - Domain: 3317 test đạt (`tax_report.test.ts`: tách VAT/PIT, ranh giới tháng giờ Việt Nam, CSV và chống chèn công thức, `exportTaxReport` đủ nhánh, `taxPayeeOf`).
  - Functions: 1186 đạt (`tax_export.test.ts` 16 + adapter, seed, prune; callable: support và sales `staff_forbidden`, thiếu TOTP `mfa_required`, finance và admin nhận link 300 giây, tổng CSV bằng tổng báo cáo, một dòng audit `tax.export`, `not_eligible` không đọc gì, tháng trống chỉ có dòng tiêu đề, lỗi audit không có URL).
  - Dashboard: 388 đạt, lint, typecheck, `npm run build` sạch (`TaxScreen.test.tsx`, `read/tax.test.ts`, `labels-tax.test.ts`, `StaffShell-money.test.tsx`).
  - Root `npm run typecheck` sạch.
  - Chưa chạy trong sandbox: `firebase/rules-test` (test từ chối đọc `exports/tax/**`) và test tích hợp Functions (cần emulator).
- **Playwright**: Playwright trên emulator (MFA bypass): 22 passed, 1 skipped (mfa.spec, cố ý), gồm `tax.spec.ts` 2/2 (controller chạy 2026-11-15). `apps/dashboard/e2e/tax.spec.ts` (finance mở `/staff/tax?period=<tháng của seed-payout-an-1>`, thấy hàng của An với `•••• 4821` và không có số đầy đủ trên màn, xuất qua `DecisionDialog` có lý do, nhận download có URL `data:` và tên `bao-cao-thue-YYYY-MM.csv`, tệp có số đầy đủ dạng `"=""…"""`; sales vào `/staff/tax` nhận trang 403) và `roles.spec.ts` (menu finance và admin có Thuế). Không cần chạy tuần tự hay seed lại: xuất chỉ thêm một dòng audit và một tệp tự xoá sau 7 ngày.
- **Sau review cuối (fix wave, booking-be 13bcd90):**
  - Ruling 8: ô số định danh chỉ gồm chữ số được ghi `="079012344821"` (trong CSV: `"=""079012344821"""`) để Excel giữ số 0 đầu; chỉ cột số định danh và chỉ khi toàn chữ số, ô văn bản tự do vẫn qua lớp chặn công thức. Test miền cho CCCD và MST bắt đầu bằng 0; `tax.spec.ts` kiểm dạng này.
  - `idLast4` chỉ nhận khi khớp `/^\d{4}$/` (không thì null, hiện "—"), cả lúc đọc cho báo cáo lẫn lúc ghi khi xác minh (không ghi nếu 4 ký tự cuối không phải chữ số).
  - `exportTaxReport` chạy 60 giây; số đầy đủ giải mã song song từng đợt 10, giữ thứ tự dòng.
  - Mã số thuế cắt khoảng trắng một cách (`approvedTaxCode` trong miền) cho cả màn và CSV; mã chỉ có khoảng trắng coi như không có.
  - Lỗi ghi audit sau khi lưu tệp thì xoá tệp (cố gắng hết sức, chỉ log đường dẫn) rồi ném lại lỗi; `TaxFileStore.remove` là cổng mới.
  - `seed/README.md` ghi số CCCD thử của An và `idLast4`.
- **Seed**: `users/{AN}/private/identity` có `idNumberEnc` và `idLast4` (4821); `seed-payout-an-1` trả `now − 35 ngày`.

## Còn mở (hoãn đến review cuối hoặc ticket sau)

Ruling 7:

- Hai bộ ánh xạ khoản chi (dashboard và Functions) có thể lệch ở tài liệu hỏng (thiếu `amountNet`, trạng thái lạ); gom về một ánh xạ ở miền hoặc thêm test chạy cả hai trên cùng một fixture.
- `StorageFileSigner` không đặt `response-disposition`, nên tệp tải ở production tên `{ulid}.csv` thay vì `bao-cao-thue-YYYY-MM.csv` (dùng chung với xuất dữ liệu, chưa đổi).
- Truy vấn khoản chi theo tháng không `limit` ở cả hai adapter, không có cảnh báo khi một tháng quá lớn.

Từ review C1 (không sửa):

- `cell()` (chống chèn công thức) chỉ chặn `=`, `+`, `-`, `@`; OWASP còn liệt kê tab và CR đứng đầu.
- `periodBounds` nhận năm dưới 100 (như `0050-01`) rồi `Date.UTC` đổi thành 19xx; nên từ chối năm dưới 2000.
- Tách VAT dùng tỉ lệ VAT của chính sách hiện hành trên `taxRateBp` đã chụp; nếu đổi chính sách thì khoản chi cũ tách sai (hiện đúng vì D10 dùng chính sách mặc định).
- Test ranh giới đầu và cuối tháng chưa kiểm đúng thời điểm đầu (gồm) và cuối (loại); test "tháng hiện tại" chỉ kiểm `doesNotThrow`.

Từ review cuối (hoãn, minor 4, 5, 6):

- Ở nơi D10 từ chối, màn vẫn có nút "Xuất tệp CSV" và bấm vào chỉ thấy câu chung `error.not_eligible`; nên có thông báo riêng (ví dụ `s23_13.export_unavailable`).
- Tháng đang mở: màn đọc báo cáo lúc tải trang còn callable dựng lại lúc bấm, nên tệp có thể có khoản chi mới hơn màn; quy tắc "tổng trên màn bằng tổng trong tệp" chỉ chắc với tháng đã đóng (ghi chú vào spec hoặc toast khi `rows` khác `report.totals.payees`).
- `expiresAt` tính từ `now` đầu lời gọi còn bộ ký dùng `Date.now()` lúc ký, nên hạn báo sớm vài mili giây (an toàn, chỉ là thẩm mỹ).

Từ review C2 và fix 1 (không sửa):

- Chưa có test tích hợp Functions cho callable (test đơn vị với fake đã phủ cùng logic; truy vấn Firestore và lưu Storage thật chỉ phủ bằng test adapter ghi lại và build).
- TDD: use case miền `exportTaxReport` viết trước test của nó.
- Chip tháng dùng `<details>` gốc: Escape và bấm ngoài không đóng menu; chọn lại đúng tháng đang chọn không mount lại nên menu vẫn mở (chỉ thẩm mỹ).
- Tháng đang chọn cũ hơn 12 tháng được thêm cuối danh sách, không sắp xếp (chỉ vào được bằng URL).
- Test rules cho `exports/tax/**` đã viết nhưng chưa chạy ở emulator (mặc định vốn đã từ chối).

## Chữ tiếng Việt mới (`apps/dashboard/src/messages/vi.ts`; chủ sản phẩm xem lại)

Chữ `s23_13.*` (mock chỉ có tiêu đề, phụ đề, chip tháng, tên bốn ô, tên cột và nút "Xuất tệp CSV"; phần còn lại là chữ mới):

| Khoá | Chữ |
|---|---|
| `nav.tax` | Thuế |
| `s23_13.title` | Báo cáo thuế |
| `s23_13.subtitle` | Theo ngày chi, giờ Việt Nam · tỉ lệ 5% GTGT + 2% TNCN cho cá nhân, 0% cho studio (chờ kế toán xác nhận) |
| `s23_13.months_label` | Chọn tháng (tên truy cập của chip: "Chọn tháng: Tháng {month}/{year}") |
| `s23_13.month` | Tháng {month}/{year} |
| `s23_13.card.gross` / `vat` / `pit` / `payees` | Đã chi gộp / Thuế GTGT / Thuế TNCN / Người nhận |
| `s23_13.col.payee` / `kind` / `id` / `payouts` / `gross` / `vat` / `pit` / `net` | Người nhận / Loại / Giấy tờ / Lần chi / Gộp / GTGT / TNCN / Thực nhận |
| `s23_13.kind.individual` / `artist` / `studio` / `organizer` | cá nhân / NAG / studio / tổ chức |
| `s23_13.id_masked` | •••• {last4} |
| `s23_13.id_masked_business` | MST •••• {last4} |
| `s23_13.table_label` | Báo cáo thuế theo người nhận |
| `s23_13.empty` | Không có khoản chi nào trong tháng này |
| `s23_13.load_error` | Không tải được báo cáo thuế |
| `s23_13.export` | Xuất tệp CSV |
| `s23_13.export_title` | Xuất báo cáo thuế tháng {month}/{year}? |
| `s23_13.export_summary` | Tệp CSV có số định danh đầy đủ của {payees} người nhận. Link tải có hiệu lực 5 phút, tệp tự xoá sau 7 ngày. Mỗi lần xuất được ghi vào nhật ký. |
| `s23_13.export_confirm` | Xuất tệp |
| `s23_13.exported` | Đã xuất tệp CSV |

Nhãn nhật ký thêm ở C2 (`audit.action.*`; ba nhóm `staff.*`, `approval.*`, `file.view` có từ trước):

| Khoá | Chữ |
|---|---|
| `payout.approve` | Duyệt lần chi |
| `payout.execute` | Chạy lần chi |
| `payout.hold` | Tạm giữ lần chi |
| `payout.resume` | Tiếp tục lần chi |
| `payout.rerun` | Chạy lại lần chi |
| `transfer.assign` | Gán chuyển khoản |
| `transfer.refund` | Hoàn tiền chuyển khoản |
| `transfer.dismiss` | Đóng chuyển khoản |
| `refund.retry` | Gửi lại khoản hoàn |
| `refund.mark_manual` | Ghi nhận hoàn thủ công |
| `instant.staff_cancel` | Huỷ yêu cầu Chụp ngay |
| `tax.export` | Xuất báo cáo thuế |
