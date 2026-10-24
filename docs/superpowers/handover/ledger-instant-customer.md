# Sổ bàn giao — Chụp ngay: app khách S13.01–S13.08 (#140, PR 2)

- **Issue:** [#140](https://github.com/thanhngochoang/booking/issues/140) (PR 2 của 2: Tasks 1–7 của plan khách; PR 1 là [#285](https://github.com/thanhngochoang/booking/pull/285), sổ [`ledger-instant-dispatch-provider.md`](ledger-instant-dispatch-provider.md)). Tiền là [#202](https://github.com/thanhngochoang/booking/issues/202) (Task 8 của plan khách, sau Task 11 của plan điều phối).
- **Plan:** [`../plans/2026-10-07-s13-instant-customer.md`](../plans/2026-10-07-s13-instant-customer.md) · **Spec:** [`../specs/2026-10-01-instant-booking-design.md`](../specs/2026-10-01-instant-booking-design.md) (§2.1 luồng khách, §4 tiền và bảng huỷ, §8 màn, §9 riêng tư, §10 tình huống biên) · **Màn:** [`../specs/screens/instant.md`](../specs/screens/instant.md) (mục "S13 khách").
- **Nhánh:** `plan/140-instant-customer`, từ `origin/develop` eac953ce (đã có PR 1). PR vào `develop`.

## Đã làm

| Task | Commit | Kết quả |
|---|---|---|
| 1 Mock phía khách | 41c73e5c, e80e2c00 | Khung `#S02.01-instant`, `#S02.06-instant`, `#S13.01-noloc`, `#S13.02-summary`, `-round`, `-empty`, `#S13.05-arrived`, `-stale`, `#S13.06-confirm`, `-done`, `#S13.08-done`; chú thích ghi rõ #140 chưa có tiền ("Gửi lời mời" ở mọi lượt). Kiểm hình trong trình duyệt: không khung mới nào tràn màn điện thoại. |
| 2 S13.01, lối vào | 57230adb, 3117eed2 | `InstantRequestScreen`/`Controller`, `InstantDraft` (giữ sống, theo tài khoản), `InstantEntryCard` (S02.01), `InstantFindButton` (S02.06), route `/instant` có chốt khách, `instantActiveRequestIdProvider`, `EscrowNotice.maxLines`, `LocationRepository.openLocationSettings`. Một vòng sửa. |
| 3 S13.02, `/instant/:id` | 0e8b7c17, d2440f34 | `SwipeDeck` (core), `ChooseController`/`ChooseView` (bộ thẻ, tóm tắt, hết lượt, trống), `InstantFlowScreen` (đổi view theo trạng thái), `instantTickDeadlines`/`nextTickDelay`, route `/instant/:id`, `AppIcons.personSearch`/`hourglass`. Một vòng sửa. |
| 4 S13.08 khách, màn đã đóng | 82f63d4b | `showCustomerCancelSheet` (bản tính thử của server, hỏi lại ở mốc), `ClosedView`, chữ đỏ "Huỷ" ở S13.02 đã gửi lời mời, `PolicyTable.whenMaxLines`; đích push `/instant/{id}` đã có trong danh sách của #138. |
| 5 S13.03, S13.04, S13.07 | f6b4736a, 1d276988, c34a3903 | `WaitingView`, lớp phủ S13.04 trong `InstantFlowScreen`, `NoMatchView`, `InstantTickScheduler`, `InstantIconDisc`. Một vòng sửa. |
| 6 S13.05, S13.06 | ab9d92c6, 0932bd3e | `TrackingView` (bản đồ sơ đồ, ETA theo từng điểm, chờ cập nhật, trễ, huỷ miễn phí đếm ngược), `ShootingView` (đang chụp, chờ xác nhận), `DoneView`, `InstantBoldPart`, `InstantStatusBadge`, `instant_meta.dart`; core `MapPreview.center`, `MetaPart.text(bold:)`, `CountdownText.interval`, `AppIcons.taskAlt`. Một vòng sửa. |
| 7 Test hai bên, tài liệu | 9fe39e56 | `test/support/instant_simulator.dart` (một backend trong bộ nhớ, hai mặt khách/thợ, theo luật `packages/domain`), `instant_two_party_test.dart` (10 test); `InstantWorld`/`InstantCustomerWorld` nhận `repository` và đồng hồ chung; mock (S13.02, S13.03, S13.08-done), `chooseLike` "Chọn người này", `screens/instant.md` mục "S13 khách", bảng mã spec chính, spec §8, `shared-components.md`, bảng chữ của plan, dòng "Superseded" ở plan I5 cũ, sổ này. |
| Rà soát cuối | — | Approved (0 Critical, 0 Important; toàn nhánh `eac953ce..9fe39e56` đã kiểm tra). |

## Quyết định (Decisions 1–14 của plan khách, mỗi dòng một ý)

1. Thanh toán ở lần "Thanh toán {giá} và gửi lời mời" đầu tiên, trước mọi lời mời — **#202 (Task 8)**. Ở #140 nút là "Gửi lời mời" ở mọi lượt, `invite` trả `InstantInvited` (gửi ngay) hoặc `InstantPriceChanged`.
2. Phương thức trả (#202): `PayMethodPicker` của #129 trên tóm tắt S13.02 (Chuyển khoản QR chọn sẵn, MoMo, ZaloPay); phương thức cũng là nơi nhận hoàn ở S13.07/S13.08. #140: không có ô chọn; chữ nơi nhận hoàn mặc định "tài khoản đã chuyển".
3. Điểm hẹn = vị trí GPS hiện tại + tên khách gõ (≤ 80, bắt buộc); một ghim "Điểm hẹn · {tên}"; không kéo ghim, không tìm địa chỉ. Không có vị trí → `#S13.01-noloc`; Chụp ngay cần vị trí.
4. Một route `/instant/:id`, đổi view theo trạng thái; sheet S13.08 không có route (`/instant/:id/cancel` của spec không thêm).
5. S13.04 hiện khi màn thấy `searching → assigned`, hoặc mở một yêu cầu `assigned` có `assignedAt` dưới 60 giây; ngoài ra vào thẳng S13.05.
6. Tick: S13.03 ở 1 giây sau hạn lời mời muộn nhất và ở `searchDeadlineAt`; S13.02 đã gửi lời mời ở `searchDeadlineAt`; S13.06 ở `shootEndsAt`; mọi view một lần khi app quay lại; tick lỗi im lặng.
7. ETA đường thẳng (`haversineKm` → `estimateEtaMinutes`) từ từng điểm; 3 phút không điểm → "Đang chờ cập nhật vị trí"; quá `lateDeadlineAt` → dòng trễ và "Huỷ (hoàn 100%)".
8. Số tiền huỷ chỉ từ server (`cancel(dryRun: true)`); hàng của luật được tô với "(bây giờ)"; phần chia khi đã đến là cấu hình `instantArrivedCancelPhotographerPercent` (mặc định 50) chụp lại trên yêu cầu; không phần trăm nào viết cứng trong chữ. Thợ nhận 100%, phí nền tảng 0% cấu hình được; khách không thấy phí.
9. Lối vào S02.01 (thẻ dưới dòng chào) và S02.06 (nút viền trên dòng đếm), chỉ khi cờ bật và là khách; Trang chủ đọc `myActiveRequestId()` một lần mỗi lần mở; `conflict` khi tạo cũng mở yêu cầu đang mở.
10. Hỏi quyền thông báo (`CustomerInstantPrimer`) sau lần gửi lời mời thành công đầu tiên ở #140; #202 chuyển sang sau khi trả xong.
11. S13.05: "Nhắn tin" → `/chat/{chatId}`; "Liên hệ" là `PhotographerContactAction` mở khoá; chỉ khi đã có thợ.
12. Sau khi xong: báo ảnh về trong 48 giờ; không có đánh giá (#130) và khiếu nại (S18, #142); câu "có vấn đề thì báo trong 24 giờ" chỉ là thông tin.
13. "Đặt lịch thường" (S13.02 trống, S13.07, không có vị trí) → `/action`; yêu cầu đang mở vẫn mở.
14. Cờ: #202 đặt `kInstantEnabled = true` (hai phía cùng lúc, khi có tiền) và sửa test S17.02; #140 để `false`.

## Phán quyết khi làm

- **Chung:** #140 mở lại sau khi PR #285 tự đóng nó; PR 2 nhận việc trên `plan/140-instant-customer` (đầu plan).
- **Task 1:** khung S02.01-instant giữ "97% (58)" thừa hưởng từ S02.01 (nhỏ, giữ). `matchBodyCustomer` và các khoá `instantStatus*`/`instantError*` phía khách chưa có trên develop → Tasks 2–6 thêm; `checkPayment`/`InstantPaymentNeeded` là của #202.
- **Task 2:** chấp nhận các khác biệt hợp đồng: `submit()` trả `InstantSubmit?` (sealed), `packageCode` rỗng = gói mặc định, `instantActiveRequestIdProvider` đọc lại khi tạo/làm mới, tách test world, `EscrowNotice.maxLines`, Tìm thợ mở yêu cầu đang mở (theo chú thích mock). Nháp xoá qua `ref.listen` trên uid (đổi tài khoản, đăng xuất), không xoá ở uid đầu tiên lúc đăng nhập còn đang tải. Chuyển hướng `/instant` chỉ khi cờ tắt hoặc vai đã biết là thợ (không chuyển khi hồ sơ đang tải); `/instant/:id` cùng chốt.
- **Task 3:** đổi ảnh bằng chạm nửa trái/phải (vuốt ngang là chọn/bỏ qua) — mock đã sửa ở Task 7; `choosePriceChanged` và `chooseEscrow` giữ nguyên chữ mock (cờ tắt ở #140; đúng từ #202); "Xem 5 người khác" nằm trên ♥ bị vô hiệu ở cuối bộ thẻ; chốt khách ở `/instant/:id`. Hỏi quyền thông báo ở lần gửi đầu tiên **tới được ai đó** (`invitedTotal == 0`), không theo `!committed` (domain đặt `committedAt` cả khi không mời được ai — đã kiểm `instant_requests.ts`).
- **Task 4:** bản tính chưa trả không tô hàng nào (domain `UNPAID` không có hàng; tô theo trạng thái cần logic thời gian ở app, trái Decision 8); `PolicyTable.whenMaxLines` mặc định 1 (S05.03 không đổi); vắng mặt khi chưa trả → `cancelledNoMoney` (không bao giờ "0₫ (0%)"); chữ đỏ "Huỷ" ở S13.02 đã gửi lời mời (khung mock thêm ở Task 7, cùng câu "vắng mặt chưa trả → Không có khoản tiền nào." ở chú thích `#S13.08-done`); `conflict` ở bản tính thử đóng sheet với lỗi chung (`conflict` của domain ở bản tính thử không bao giờ thử lại được); hỏi lại bản tính khi trạng thái đổi hoặc qua mốc, nút xác nhận vô hiệu khi đang tải lại.
- **Task 5:** S13.04 là trạng thái trong màn luồng (như phía thợ), không đẩy route; hẹn giờ tick gom vào `InstantTickScheduler`, một nguồn `latestPendingExpiry` cho đếm ngược và tick; `waitingRowMeta`/`waitingRowMetaNoRating` gộp thành `waitingRowEta` (`MetaLine` vẽ cà chua); "Đã gửi lời mời cho {n} người" chỉ đếm người được mời của lượt — mock "3 người" sai, đã sửa ở Task 7; hàng bận ghi "vừa nhận việc khác" không kèm tên (mock thắng brief). Ghi chú khi chưa trả bỏ cả câu giữ tiền lẫn "không trả thêm" (khoá mới `waitingNoteUnpaid`); `matchBodyCustomerNoEta` khi không biết ETA.
- **Task 6:** thêm vào core (tương thích ngược, có tài liệu): `MapPreview.center`, `MetaPart.text(bold:)`, `CountdownText.interval`, `AppIcons.taskAlt`. S13.05 chưa trả: không có nút gọi "Liên hệ" (luật liên hệ), "Huỷ" thường, khoá mới `trackingLateUnpaid`. Chỉ nghe vị trí khi `en_route` (chốt ở provider). Khác mock được chấp nhận: "Về trang chủ" ở chân màn (nút hành động của `EmptyState` là nút chính), "Nhắn tin"/"Liên hệ" chia đều, vòng "38 phút" (như S14.03).
- **Task 7:** ô trạng thái của bảng mã chỉ là link #140 (luật "trạng thái = link" thắng chữ "✅ đã làm (#140)" của brief). Nhãn đọc màn hình của ♥ theo mock: `chooseLike` = "Chọn người này". Bảng chữ của plan sửa theo khoá đã làm (`waitingRowEta`, `waitingRowUnavailable`, `waitingNoteUnpaid`, `matchBodyCustomer`/`NoEta`, `trackingEtaBold`, `trackingLateUnpaid`, `chooseUnpickA11y`, `instantNotFound*`). Test hai bên dựng hai app trong một `IndexedStack` (một hiện, một ẩn nhưng vẫn nghe) thay vì hai app cạnh nhau; trạng thái "đã trả" trong test dùng `InstantSimulator.markPaid` thay cho bước trả của #202. Bộ giả lập: hàm huỷ đăng ký của luồng không trả `Future` (future huỷ của nguồn broadcast thuộc root zone làm `.first` không bao giờ xong dưới fake async của widget test).

## Bỏ qua theo quy tắc chung

- Không build lên thiết bị, không bước pin/hiệu năng, không iOS: **cảm giác vuốt thẻ (S13.02) và hình bản đồ sơ đồ (S13.01, S13.05) chưa được xem trên điện thoại thật**, chỉ qua widget test và mock.
- Plan khách không đổi rules hay chỉ mục; không có test emulator nào bị bỏ ngoài những gì sổ PR 1 đã ghi.

## Tách #140 / #202

- **#140 (PR này) không có tiền và cờ tắt**: "Gửi lời mời" gửi ngay ở mọi lượt, không `pending_payment`, không chọn phương thức; mọi yêu cầu chưa trả nên S13.08 nói "Bạn chưa thanh toán nên không có khoản tiền nào.", màn đã đóng nói "Không có khoản tiền nào.", S13.03/S13.07 không nói giữ tiền, không có nút gọi "Liên hệ". `kInstantEnabled = false`: không lối vào nào hiện cho khách thật. Các trạng thái đã trả (hoàn, phí, tiền giữ) có code và test trên dữ liệu giả.
- **#202 (Task 8 của plan khách)**: bước trả ở `ChooseController.send` trên S04.04 chung của V1 (`openPayment`, `InstantPay`, `/instant/:id/pay`), ô chọn phương thức, "Thanh toán tiếp" khi `pending_payment`, primer sau khi trả, bật cờ và sửa test S17.02; mở rộng test hai bên ("lần mời đầu trả một lần trên S04.04 rồi mới gửi").
- **Ghi chú cho #202:**
  - Đua ở mốc: lệnh huỷ thật chưa gửi luật/số tiền đã báo giá; #202 nên gửi kèm (`expectedRule`/`expectedRefundVnd`) và server trả `conflict` khi lệch, để khách không bị trừ khác số đã thấy khi bấm đúng lúc qua mốc 2 phút.
  - Yêu cầu đã trả mà hoàn 0 (cấu hình `instantArrivedCancelPhotographerPercent` = 100) hiện "Không có khoản tiền nào." ở màn đã đóng (cấu hình cực đoan; xem lại chữ khi có tiền).
  - `choosePriceChanged` "… trước khi thanh toán" và `chooseEscrow` đúng nghĩa từ #202.
- **Ghi chú phát hành cho #202:** khi #202 được deploy, Chụp ngay hiện ở Trang chủ và Tìm thợ ảnh cho **mọi khách**; công tắc phía server là `instant_config/current.enabled` (tắt thì mọi lời mời bị từ chối `not_eligible`, khách vẫn huỷ được).

## #202 — bước trả tiền (Task 8 của plan khách)

Nhánh `plan/202-instant-payments`, cùng PR với Task 11 của plan điều phối (sổ [`ledger-instant-dispatch-provider.md`](ledger-instant-dispatch-provider.md), mục "#202 — tiền").

- **Tên V1 như đã thấy trên develop:** `PaySubject` (sealed) thêm `InstantPay(requestId)`; `payPathOf` → `/instant/{id}/pay`; `openPayment(context, ref, subject:, instructions:)`; `PaymentScreen(subject:, initial:)`; `PaymentController` (`seed`, `renew`, `check`, `PayOpen`/`PayDone`/`PayLoading`/`PayFailed`); `FakeTransferButton` → `FakeTransferSheet(paymentId:)` → `PaymentsRepository.confirmFake(paymentId, kind:)` (trả mã kết quả, `paid` khi chuyển đúng); `PaymentInstructions` phẳng. Không có `FakeWalletSheet`: ví ở chế độ giả cũng dùng `FakeTransferSheet` (đúng như Decision 1). `InstantRepository.checkPayment` trả `bool` (sổ Task 11 mục 13), không phải `PaymentCheck` của V1.
- **Keo nối:** `lib/features/instant/instant_payment.dart` — `openInstantPayment` (mở S04.04 sau `InstantPaymentNeeded`), `inviteInstantAgain` ("Thanh toán tiếp", "Tạo QR mới", S04.04 mở lại không có hướng dẫn: gọi lại `invite` với `pendingInviteIds`, số tiền và phương thức của yêu cầu; server dùng lại khoản đang mở), `instantPayMethodOf` (chọn > phương thức yêu cầu đang chờ > Chuyển khoản QR), `instantRequestPath`.
- **S13.02:** lượt đầu (`!committed`) có mục "Phương thức thanh toán" + `PayMethodPicker` (Chuyển khoản QR chọn sẵn) và nút "Thanh toán {giá} và gửi lời mời" (`choosePayAndInvite`); lượt sau "Gửi lời mời", không có ô chọn, `invite` không gửi `payMethod`. `pending_payment` → thẳng vào tóm tắt (nhãn mã màn `summary`) với người đang chờ (`pendingInviteIds`), ô chọn phương thức (chọn sẵn phương thức đang chờ) và "Thanh toán tiếp" (`choosePayContinue`); không có "Bỏ chọn" và "Xem 5 người khác" (server từ chối vòng mới khi đang chờ trả: `conflict`). Chữ đỏ "Huỷ" vẫn có.
- **Mô hình:** `InstantRequest.pendingInviteIds` (đọc từ `instant_requests/{id}.pendingInviteIds`) — cần cho "Thanh toán tiếp" sau khi mở lại app.
- **S04.04 cho `InstantPay`:** mã màn `S04.04` nhãn `instant` (theo mẫu `ticket`/`fee` của V1; brief viết `ScreenCode(instantChoose, label: 'pay')` cho "sheet trả tiền" — không có sheet riêng nên giữ mã S04.04). Mở khi yêu cầu `pending_payment` (hoặc ngay sau `invite`, trước khi listener kịp báo); rời khi yêu cầu rời `pending_payment`: đã trả → `/instant/{id}?paid=1`, hết hạn trả (về `choosing`) hoặc mất → `/instant/{id}`. "Tạo QR mới" = mời lại cùng người, cùng phương thức. "Kiểm tra lại" (ví) = `checkInstantPayment`. Nút quay lại khi QR hết hạn về `/instant/{id}`.
- **Primer (Decision 10):** bỏ khỏi `ChooseController.send`; `InstantFlowScreen(justPaid:)` hỏi một lần khi mở bằng `?paid=1` và yêu cầu đã `paid` — cả khi S13.01 đã mở yêu cầu bằng `go` (cùng trang, `didUpdateWidget`), rồi bỏ `?paid=1` (`replace`, giữ trạng thái). S04.04 luôn gọi `seed` sau khung đầu (cả khi không có hướng dẫn): với `InstantPay`, `seed(null)` quyết định rời khi yêu cầu không chờ gì. Khác brief (`go('/instant/{id}')`): thêm `?paid=1`, giống `/b/{id}?paid=1` của đặt lịch.
- **Quay lại app khi `pending_payment`:** `InstantFlowScreen` gọi `checkPayment` một lần mỗi lần resume (cùng tick sẵn có); lỗi im lặng.
- **Cờ bật:** `kInstantEnabled = true`; test S17.02 đổi thành "hàng Chụp ngay hiện" (+ khách chỉ có công tắc Push). `DiscoveryWorld` mặc định tắt Chụp ngay (`instantEnabled: false`, repo giả) để test Trang chủ/Tìm thợ không phụ thuộc cờ; `work_screen_test` `_pump` tắt cờ (thẻ Live Shutter có nhóm test riêng).
- **Bộ giả lập hai bên:** `InstantSimulator` có tiền như server: lượt đầu cần `payMethod`, chờ ở `pending_payment` với khoản `inst_{id}_{n}` (dùng lại khi còn hạn, cùng phương thức), `payments` (`confirmFake` chuyển đúng → gửi lời mời), hết hạn trả → `choosing`; `markPaid` bỏ. Test hai bên trả qua S04.04 thật ("Giả lập chuyển khoản" → "Chuyển đúng"); thêm "the first invite pays once on S04.04 and only then are the offers sent"; "choosing, unpaid" thành "pending_payment, unpaid: no money".
- **Ghi chú phát hành (#202):** khi deploy, Chụp ngay hiện ở Trang chủ và Tìm thợ ảnh cho **mọi khách**; công tắc phía server là `instant_config/current.enabled` (tắt thì mọi lời mời bị từ chối `not_eligible`, khách vẫn huỷ được).

## Câu hỏi cho chủ dự án

1. Bản đồ thật (tile) và tìm địa chỉ cho điểm hẹn (chung với câu hỏi 2 của plan điều phối)? Mặc định: bản đồ sơ đồ + tên gõ.
2. Khách từ chối vị trí: mặc định không có Chụp ngay (mời "Đặt lịch thường"); phương án khác: chọn tâm một khu (ETA kém chính xác, thợ chỉ dựa vào tên điểm hẹn).
3. Đánh giá sau buổi chụp ngay trước khi có cà chua/gạch cho chụp ngay (#130)? Mặc định: không có.

## Hoãn

Từ plan:
- Tile bản đồ thật, tìm địa chỉ và geocoding ngược cho điểm hẹn; ETA trực tiếp từ API tuyến đường (câu hỏi 1; so sánh chi phí ở plan điều phối ≈ $25/tháng ở mức (c)).
- Chọn khu khi khách từ chối vị trí (câu hỏi 2).
- Đánh giá và duyệt giao ảnh sau chụp ngay (#130), khiếu nại trong 24 giờ (S18, #142).
- Tổ chức trung gian thanh toán thật (#129) và sheet chọn nơi nhận hoàn S22.04 (#141).
- "Thường có người nhận trong khoảng {n} phút" ở S13.01 (cần dữ liệu thời gian ghép).
- Yêu cầu chụp ngay trong S05.01 Đặt lịch và lịch sử thanh toán S22.01 (chưa có danh sách; thẻ Trang chủ mở yêu cầu đang mở).
- "Xem hồ sơ đầy đủ" từ thẻ vuốt (câu hỏi 7 của spec).

Từ các task (nhỏ, hoãn):
- Task 2: `ensureVisible` một khung sau khi đóng bàn phím có thể tính theo khung nhìn còn bị bàn phím thu nhỏ.
- Task 3: `choose_view.dart` ~870 dòng (tách sau); toast "người bận" khi chỉ một phần người được chọn bận phụ thuộc thời điểm (S13.03 có thể đã mở trước khi `invite` trả lời); thứ tự import trong `instant_flow_screen_test` và một đoạn định dạng lại không liên quan trong `choose_view_test`.
- Task 5: `_Amounts` (sheet huỷ) và `InstantBoldPart` gần giống nhau (khác kiểu chữ của phần phí); một snapshot gộp `searching → en_route` không hiện S13.04 (đúng chữ Decision 5 nhưng có thể bỏ lỡ khoảnh khắc match).
- Task 6: `kInstantAutoComplete` viết cứng 2 giờ của domain (theo plan); "0:00:00" hiện tới khi bước 15 phút của server hoàn tất yêu cầu (không có tick ở `finishedAt + 2 giờ`).
- PR 1 (đợt rà soát cuối): sheet huỷ phía thợ (`provider_cancel_sheet.dart`) đưa "Thử lại" cho một `conflict` ở bản tính thử, mà `conflict` của domain ở đó không bao giờ thử lại được (nên đóng sheet với lỗi chung như phía khách).

## Rà soát cuối

- Rà soát cuối toàn nhánh (`eac953ce..9fe39e56`, Tasks 1–7): **Approved** (0 Critical, 0 Important). Các mục nhỏ hoãn đã ghi ở mục "Hoãn" phía trên.
