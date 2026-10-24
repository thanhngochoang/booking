# Ledger: S18 · Khiếu nại (#142)

Plan `docs/superpowers/plans/2026-10-07-s18-disputes-help.md`, Tasks 7–13 (Tasks 1–6 là #204, đã vào develop ở #235; ledger của phần đó: `ledger-s18-help.md`). Nhánh `plan/142-s18-disputes`, cắt từ `origin/develop` 4b24b14a (đã có #204, #152 hai mốc và bàn giao, #129/#200 V1, #201 V2, #138 thông báo). Đặc tả màn: `docs/superpowers/specs/screens/disputes-help.md`; mô hình dữ liệu: `data-model/domain-model.md` mục 2.15, mục 5 "Khiếu nại", bất biến 49–53; `relational-schema.md` mục 2.5a.

## 1. Đã làm theo task

| Task | Commit | Nội dung |
|---|---|---|
| 7 Domain | `749b4e61`, sửa `4fa73916` | `dispute.ts` (hằng, kiểu, `REASONS_BY_SUBJECT`, `parseOpenDisputeInput`, `parseResolveDisputeInput`, `disputeWindow`, `outcomeAmounts`, `disputeThreadId`), `dispute_ports.ts`, `dispute_use_cases.ts` (`openDispute`, `resolveDispute`, `dispatchDisputeRefund`), `dispute_notifications.ts` (`notifyDisputeChange`), `MemoryDisputeStore`; nhánh `dispute` của `sendSupportMessage` và `notifySupportMessage`; `Payment.dispute` mở rộng; `Booking.disputeId`; xoá `open_dispute.ts` |
| (controller) | `53fff87b` | `booking_sweeps` bước 7 đọc booking trước khi ghi (lỗi có từ trước, mục 2) |
| 8 Functions | `d548570d` | `FirestoreDisputeStore`/`FirestoreDisputeTx`, `dispute_mapping.ts`, `live_dispute.ts`, callable `openDispute` (trỏ sang use case mới) và `resolveDispute`, mapping `disputeId` của booking/đăng ký vé và `payments.dispute`, rules `disputes`, Storage `disputeEvidence`, hai index `disputes`, seed |
| 9 Functions | `9cefd945`, `7b17dbe0`, sửa `0e435289` | trigger `onDisputeWrite`, CLI `npm run disputes`, `support_message_created` chuyển tin của hai bên; fake giao dịch nghiêm (đọc sau ghi), log gửi hoàn, hoàn khiếu nại của vé, thu nhập seed tính vé; dấu `opening` |
| 10 App data | `8a2ac00d` | `lib/data/disputes/*` (`Dispute`, `DisputeRepository`, `FirestoreDisputeRepository`, provider), `Booking.disputeId`, `EventRegistration.disputeId`; bỏ `BookingRepository.openDispute`, `BookingRules.canCustomerDispute`; trỏ lại người gọi S05.06 |
| 11 S18.01 | `cc0ca86d`, `a2c687f6` | sheet mở khiếu nại, `dispute_entry.dart`, điểm vào S05.02 / S05.06 / S11.04, dải khiếu nại S05.02 |
| 12 S18.02 | `b4227386`, `a49ea1f8`, sửa `06e1b8c2` | màn chi tiết, `DisputeOutcomeCard`, mục "Khiếu nại của bạn" ở S18.03, `KeyValueBox`/`InlineToast` vào core, `SupportThreadView.scrollHeader` + tin hệ thống |
| 13 Tài liệu | `59efdf59` | spec chính §2 và §3i.1, mô hình dữ liệu, `screens/disputes-help.md`, `shared-components.md`, `FIREBASE-SETUP.md`, ledger này |
| Final review (fix wave) | `8171a3c8`, `2cea7aa1`, commit `docs(s18): #207 hand-off, plan corrections, final review outcomes [#142]` | máy chủ S1–S4, app A1–A4, tài liệu D1–D6 (mục 13) |

## 2. Quyết định khi làm (rulings)

1. **Phạm vi**: unit = Tasks 7–13; hai blocker #204 và #152 đã đóng và có trên develop.
2. **Tiền giao hàng kẹt khi khiếu nại mốc chụp còn mở lúc hoàn thành (review Task 7, Important)**: `commit_transition` (nhánh `completed`) nhận khoản có mốc mà trạng thái tổng là `disputed` và thả mốc `delivery` nếu còn `held`, không bao giờ đụng mốc đang bị khiếu nại; `resolveDispute` thả mốc `delivery` còn `held` của booking đã `completed|reviewed` trong cùng giao dịch. Thực tế `decideTransition('finish')` vẫn từ chối khi bản sao booking là `disputed`, nên đường thả lúc hoàn thành chỉ là lưới an toàn.
3. **`resolveDispute` không tin `payment.dispute.milestone` mù quáng (review Task 7, Important)**: `frozenMilestone(p)` lấy `dispute.milestone`, nếu thiếu thì mốc `disputed` duy nhất, không có thì `conflict`.
4. **Quyết định 1 làm luôn (khiếu nại mốc bàn giao không giữ tiền mốc chụp)**: `runBookingSweeps` bước 7 nhận cả khoản có mốc với trạng thái tổng `disputed` và chỉ thả mốc `held` đã tới hạn; `FirestoreBookingStore.findReleasableEscrows` chạy thêm truy vấn `escrowStatus in ['disputed']` + `releaseAfter <= cutoff` (index sẵn có), lọc khoản có mốc, điền sau kết quả `held` tới `limit`. Khoản không mốc vẫn bị giữ cả khoản.
5. **Lỗi có từ trước, sửa trong unit này (`53fff87b`)**: `booking_sweeps.ts` bước 7 gọi `tx.getBooking` sau `tx.setPayment`/`addLedgerEntry` (cả nhánh có mốc và nhánh cũ); Admin SDK từ chối đọc sau ghi trong giao dịch, nên thả tiền trên Firestore có thể ném lỗi và dừng cả lô (store bộ nhớ không ép nên test không thấy). Sửa: đọc booking trước mọi lần ghi; test store nghiêm báo "read after write: getBooking" khi chưa sửa. Lý do sửa ở đây: Quyết định 1 của S18 mở rộng đúng đường thả tiền này.
6. **`dispute_mapping.ts` tách riêng (Task 8)**: `support_firestore.ts` (đọc khiếu nại của luồng) và `dispute_firestore.ts` (kế thừa lớp support) sẽ import lẫn nhau; `extends` qua vòng import lỗi lúc nạp module.
7. **Bản sao trên chủ thể ghi một lần mỗi giao dịch (Task 8)**: `FirestoreDisputeTx.commitMirrors()` sau use case: booking `{disputeId, escrowStatus}` + `depositRefunded: increment(refundAmount)` khi có hoàn trong cùng giao dịch; đăng ký vé `{disputeId}` + `{refundId, refundStatus}`. `getRefund` đọc trước chủ thể cần sao, để `dispatchDisputeRefund` đóng dấu `depositRefundedAt` một lần khi lệnh hoàn `done` (thông báo `refund_done` có sẵn) và chép `refundStatus` lên vé. Không đổi port của domain.
8. **Seed khiếu nại dựng bằng hàm thuần của domain (Task 8)**: `seedDocuments(now)` đồng bộ nên không chạy được use case async; dùng `parseOpenDisputeInput`, `disputeWindow`, `disputeEscrowPayment`, `disputeThreadId`, `truncateGraphemes`, `disputeOpenedText` + `bookingDisputeView`. `payment.dispute.reason` của seed là mã `photos_missing` (chữ cũ "Ảnh giao thiếu so với gói" nay nằm trong mô tả).
9. **`RegistrationDoc.disputeId`** thêm ở domain (`event.ts`, Task 8; Task 7 chưa thêm). Dòng hệ thống mở khiếu nại là hàm `disputeOpenedText(at)` (ban đầu là hằng `DISPUTE_OPENED_TEXT`, xem mục 4).
10. **CLI `disputes` theo luật môi trường của `npm run awards` (review Task 9, Important)**: chỉ dẫn "chỉ emulator" của controller là sai; Contract thắng. Không có host emulator = project thật (cần `GCLOUD_PROJECT`, `PAYOUT_ACCOUNT_KEY`); có bất kỳ host emulator = mọi host phải local và không có `GOOGLE_APPLICATION_CREDENTIALS`; môi trường lẫn lộn bị từ chối trước khi mở deps. Đây là client staff duy nhất của `resolveDispute` tới khi có S23.01. Với emulator, khoá mã hoá lấy từ `.secret.local`.
11. **Tin của hai bên trong luồng khiếu nại được báo (Task 9)**: `support_message_created` trước đây bỏ qua mọi tin không phải staff; nay chuyển tin `customer`/`provider` cho bộ quyết định (`dispute_message`); `user` và `system` vẫn bị bỏ qua trước khi đọc luồng.
12. **Dấu `opening: true` trên mô tả mở khiếu nại (review Task 9, Important)**: một lần mở = một thông báo cho bên cung cấp (`dispute_opened`); bộ quyết định bỏ qua tin có dấu này. Chỉ máy chủ ghi (rules cấm client ghi tin); Dart có thể bỏ qua trường này.
13. **Lệnh hoàn khiếu nại gửi lại bởi V2 không mang ngữ nghĩa huỷ (Task 9)**: `bookingRefundHandler` chỉ đóng dấu `depositRefundedAt` một lần, `ticketRefundHandler` chỉ chép `refundStatus` khi `registration.refundId == refund.id`; đã ghim bằng test domain, không cần sửa.
14. **Thu nhập seed tính cả vé (Task 9)**: tiền đang giữ của An 9 000 000 → 9 250 000.
15. **Người gọi S05.06 trỏ sang `DisputeRepository.open` (Task 10)**: chủ thể `booking`, máy chủ chọn mốc bàn giao; sheet tạm của Task 10 sau đó bị thay bằng `/b/:id/dispute?from=delivery` (Task 11) và đã xoá.
16. **Hết giờ chờ phía app 35 giây (Task 10)** cho `openDispute` (callable 30 giây; tiền lệ thanh toán vé).
17. **`watch()` đọc `permission-denied` là `null` (Task 10)**: rule từ chối khiếu nại không tồn tại (không có `parties`), nên S18.02 hiện "Không tìm thấy" cho cả hai trường hợp; test bằng lỗi stream giả (`disputeSnapshots`, Task 11).
18. **Cửa sổ phía app giống `disputeWindow` của máy chủ (Task 11)**: `shot` → `shotAt` + 24 giờ, `approved` → `checkUntil`, `completed|reviewed` + 24 giờ chỉ khi tiền còn giữ (booking có mốc lúc đó đã `released` nên tự ẩn). Comment của Contract (chỉ `completed`) sẽ ẩn nút với mọi booking có mốc.
19. **Dải S05.02 đọc từ bản sao trên booking (Task 11)**: `escrowStatus == disputed` = đang mở, có `disputeId` mà không `disputed` = đã có kết quả; không đọc thêm; nằm dưới thẻ booking như mock (brief ghi "trên"). Nếu bản sao thiếu `escrowStatus` thì dải đọc thành "đã có kết quả".
20. **Sheet S18.01 (Task 11)**: tắt kéo của modal (`enableDrag: false`); vuốt tiêu đề xuống, chạm ngoài, Back hỏi bỏ nội dung khi đã nhập (`canDismiss` của `showAppSheet` chỉ đọc một lần lúc mở, kéo modal bỏ qua `PopScope`).
21. **Một khiếu nại MỞ mỗi chủ thể (quyết định "một khiếu nại mỗi chủ thể, mãi mãi" đã ĐẢO)**: sau Task 11 controller chốt máy chủ từ chối `conflict` khi chủ thể đã có `disputeId` (dù đã xong), Task 12 làm theo (`b4227386`). Review Task 12 chỉ ra spec §3i.1 chỉ giới hạn khiếu nại đang mở và Quyết định 1–2 cho hai cửa sổ độc lập theo mốc, nên quyết định bị đảo (`06e1b8c2`): máy chủ chỉ từ chối khi khiếu nại đang liên kết còn `open`; kiểm "mốc của cửa sổ còn `held`" từ chối khiếu nại lại cùng mốc (`not_eligible`). App hiện điểm vào khi `disputeId` rỗng, hoặc khi khiếu nại liên kết đã xong và booking đang `approved` (cửa sổ bàn giao). Câu hỏi chủ dự án về khiếu nại lần hai được rút. Chú thích mock `#S05.02-disputed` ("Nút Báo vấn đề không hiện nữa") chỉ đúng khi khiếu nại đang mở: lệch có chủ ý.
22. **S18.02 đã có kết quả theo đúng khung `#S18.02-resolved` (Task 12)**: không còn khối tiền đang giữ, ba bước, "Mô tả & ảnh": sau khi có kết quả không mở lại được ảnh bằng chứng trong app (chủ dự án có thể muốn giữ).
23. **Badge trạng thái chữ in hoa** ("ĐANG XEM XÉT") như mọi `StatusBadge` và `.badge` của mock; dòng phụ ở S18.03 giữ chữ thường.
24. **Hàng S18.03 của bên nhận tiền (Task 12)**: tài liệu khiếu nại không có tên khách, nên bên nhận thấy phụ đề của khoản (ngày · khung giờ) thay vì tên mình; khách thấy người nhận ("ứng dụng" với sự kiện nền tảng). Đúng về quyền riêng tư.
25. **Dòng hệ thống mở khiếu nại theo mock**: "Đã mở khiếu nại · HH:mm dd/MM" giờ VN (`disputeOpenedText(at)`), app hiển thị nguyên văn. Dòng kết quả: "Khiếu nại đã có kết quả: {hoàn …/chuyển …}. Ghi chú của hỗ trợ: {note}".
26. **Dọn widget dùng chung (Task 12)**: `KeyValueBox`/`KeyValueRow` (từ S04.04) và `InlineToast` (từ S05.02) chuyển vào core; `SupportThreadView` thêm `scrollHeader` và tin hệ thống (`SystemContent`; chat hỗ trợ không đổi); `disputeReasonLabel`, `disputeReceiverName` công khai trong `dispute_entry.dart`; `Dispute.isPlatformHosted`; `EscrowNotice` thêm `icon`/`title`/`trailing`/`onTap` (dải khiếu nại không còn khung riêng); `ReasonPicker.otherField`; `formatHm` dùng chung. Ghi ở `shared-components.md`.
27. **Gửi lại quyết định của staff (final review S1)**: `resolveDispute` trên khiếu nại đã có kết quả trả lại kết quả đã lưu (và lệnh hoàn của nó) khi cùng staff gửi cùng quyết định (`outcome`, phần trăm khi chia, ghi chú): mất phản hồi rồi bấm lại không còn ra `conflict`. Staff khác hoặc quyết định khác vẫn `conflict`. Callable và CLI sau đó gọi `dispatchDisputeRefund`, vốn chỉ gửi khi lệnh hoàn còn `pending`.
28. **CLI khi gửi hoàn lỗi sau khi đã ghi quyết định (final review S2)**: in `refund <id>: decision saved; refund left pending for re-send (<lỗi>)` và thoát mã 2 (`SEND_FAILED_EXIT`), không in `refused`; 0 = xong, 1 = bị từ chối. Ghi trong `HELP`.
29. **Chọn khoản bị giữ ở một chỗ (final review S3)**: `pickSubjectPayment` chuyển từ adapter Firestore vào domain (`dispute_ports.ts`); `MemoryDisputeStore` dùng cùng hàm (khoản đã trả còn giữ tiền trước), nên bộ nhớ và Firestore chọn cùng khoản khi booking có khoản lạc.
30. **Tên tệp bằng chứng (final review S4)**: Storage chỉ nhận `disputeEvidence/{uid}/{disputeId}/{file}` với `file` khớp `^[A-Za-z0-9_-]{1,64}[.]jpg$`.

## 3. Khác biệt với Contract của plan (đã chấp nhận)

- `disputeWindow(subject, now, hasMilestones)`: tham số thứ ba (chỉ use case biết khoản có mốc hay không).
- `DisputeTx` thêm `getPayment`, `getRefund`, `getThread`; `DisputeStore` bỏ `saveRefund` (lưu vô điều kiện không giữ được "chỉ khi còn `pending`"; gửi hoàn dùng giao dịch + `mergeRefundOutcome`).
- `applyRefundToPayment` nhận `amount` cùng `escrowRefunded` (cả hai hoặc không, ép ở kiểu): `payment.refundedAmount` còn đếm khoản hoàn `fromEscrow: false`.
- Chia trên một mốc: thu nhỏ `amount` của mốc bị giữ còn phần thả rồi `releaseMilestone`; hoàn 100% thì mốc thành `refunded`.
- `Payment.dispute` lưu `milestone` và, với khoản không mốc, `prevEscrowStatus` (`prevStatus` của một mốc luôn là `held` nên không lưu).
- `dispatchDisputeRefund` theo V2 (#201 đã có): `sendRefundOnce` + `mergeRefundOutcome`; lỗi ném giữ `pending` cho lần gửi lại của V2, `awaiting_account` không gửi; đọc lại lệnh hoàn và chỉ gửi khi còn `pending`.
- `openDispute` gửi lại cùng id bởi người khác: `permission_denied`; đường dẫn ảnh trùng: `invalid_argument`. Luồng khiếu nại `ownerId: null`; mô tả đóng dấu `now + 1 ms` để xếp sau dòng hệ thống.
- Các test cũ dùng `openDispute` đã xoá được thay bằng `dispute.test.ts` / `dispute_use_cases.test.ts`; test "khoản lạc `created`" chuyển sang adapter (`findSubjectPayment for a booking picks the held payment`).
- `handleResolveDispute`: lỗi gửi hoàn sau khi đã ghi quyết định chỉ log (`dispute_refund_send_failed {disputeId, refundId, code}`), callable vẫn trả thành công; không đọc lại được khoản thì log `dispute_refund_send_skipped`.
- CLI: `runCli` trả mã thoát (0 xong, 1 bị từ chối, 2 quyết định đã ghi nhưng gửi hoàn lỗi); lỗi domain in `refused: <code>`; `list` hiện tối đa 50 và báo khi còn nữa; `--actor` theo sau bởi `--…` báo `--actor needs a uid`.
- App: `DisputeReason.fromCode` nhận `Object?`; `DisputeOutcome` không có `decidedBy`/`refundId`; khoá controller là `OpenDisputeArgs(disputeId, subject)` (id sinh trong `showOpenDisputeSheet`); `?from=delivery` không cần xử lý riêng (biến thể theo trạng thái booking, `approved` = bàn giao); `ScreenCode(…, label: 'delivery')`; thêm chuỗi `disputeSheetClose` "Đóng" và `disputeEvidencePhoto` "Ảnh bằng chứng {index}".

## 4. Sửa lời plan

- Contract và Task 13 ghi "no client used the old shape": sai, `report_delivery_sheet.dart` (S05.06 "Báo vấn đề", từ `delivery_review_screen.dart`) gọi `BookingRepository.openDispute` với dáng cũ; Task 10 trỏ sang `DisputeRepository.open`, Task 11 thay bằng `/b/:id/dispute?from=delivery` và xoá sheet.
- Comment `bookingDisputeClosesAt` của S18.01 ("completed|reviewed … completedAt + 24 h") thay bằng cửa sổ thật: `shot` → `shotAt` + 24 giờ, `approved` → `checkUntil`, `completed|reviewed` + 24 giờ chỉ khi tiền còn giữ.
- "Một khiếu nại cho mỗi chủ thể" (Contract, Review Focus 4) nghĩa là một khiếu nại ĐANG MỞ; hai mốc của booking mỗi mốc một lần.
- `DISPUTE_OPENED_TEXT` (hằng của Task 8) thay bằng `disputeOpenedText(at)` ("Đã mở khiếu nại · HH:mm dd/MM").

## 5. Ghi chú chuyển giữa các task (đã xử lý)

- Task 7 → 8: round-trip `payment.dispute.{disputeId, milestone, prevEscrowStatus}` và `disputeId`; `findSubjectPayment` của Firestore chọn khoản đã trả; `linkSubject` sao phần hoàn (booking `depositRefunded`, `depositRefundedAt`; vé `refundId`, `refundStatus`); kiểm vai staff khi resolve; thay stub `handleOpenDispute`. Xong ở Task 8.
- Task 7 phát hiện: người gọi S05.06 mà plan bỏ sót (mục 4). Xong ở Task 10/11.
- Task 8 → 9 (minor, commit riêng `7b17dbe0`): fake đọc sau ghi nghiêm + test adapter với use case thật; log lỗi gửi hoàn; handler gửi lại của V2 không áp ngữ nghĩa huỷ cho hoàn khiếu nại; thu nhập seed thiếu khoản vé. Xong.
- Task 9 → 10: `SupportMessage.opening` tuỳ chọn (Dart có thể bỏ qua).
- Task 10 → 11 (minor): tên test cũ "calls openDispute"; thay hẳn sheet tạm bằng `DisputeReason.offeredFor(deliveryCheck)` / sheet S18.01; `catch (e)` → `on DisputeError`; test `permission-denied` → `null`. Xong ở `cc0ca86d`, `a2c687f6`.
- Task 11 → 12 (minor): luật máy chủ một khiếu nại (sau đó đảo, mục 2.21); điểm vào S05.06 dùng `bookingDisputeClosesAt`; test mục đích tải ảnh không thể sai (đổi tên); dải khiếu nại dùng `EscrowNotice`; `ReasonPicker` bỏ mẹo `otherLabel: ''`; `hm()` riêng → `formatHm`. Xong ở `b4227386`.

## 6. Minor để lại

**Ứng viên FINAL WAVE: final review giữ lại, không sửa trong unit này**

- `findReleasableEscrows` của Firestore: truy vấn `disputed` áp `limit` trước khi lọc khoản có mốc ở client, khoản không mốc bị giữ có thể chiếm chỗ. Lý do giữ: chỉ khoản không mốc (trước #152, hiếm) bị giữ cả khoản mới chiếm chỗ, kết quả `held` được điền trước, tiền chỉ chậm một vòng 15 phút chứ không đi sai. Cách sửa sau: xoá `releaseAfter` khi giữ cả khoản (khoản đó rời truy vấn), đặt lại khi có kết quả.
- `findDueChecks` (`limit 100`) không loại booking đang khiếu nại, nên được thử lại mỗi 15 phút. Lý do giữ: máy trạng thái từ chối nên không ghi gì, chỉ tốn lượt đọc.
- `commit_transition` đọc khoản thanh toán ngoài giao dịch. Lý do giữ: an toàn khi máy trạng thái còn từ chối `finish` lúc booking `disputed`. **Đề xuất issue tiếp theo**: chuyển lần đọc khoản thanh toán của `commit_transition` vào trong giao dịch (đọc trước mọi lần ghi), để luật này không phụ thuộc vào lời từ chối của máy trạng thái.
- Khiếu nại mốc BÀN GIAO đã xong trên booking `approved` mà trạng thái tổng vẫn `held` (mốc chụp chưa thả) làm app hiện lại điểm vào; cùng loại: booking `completed` còn mốc chụp `held`. Máy chủ trả `not_eligible` nên tiền không sai, chỉ hiện nút thừa. Cách sửa đúng: sao mốc bị giữ (ví dụ `disputeMilestone`) lên booking để app biết, thay vì đọc khiếu nại.

**Hoãn (không sửa)**

- `payment.dispute` chỉ giữ khiếu nại gần nhất: khiếu nại thứ hai trên mốc kia ghi đè; lịch sử đầy đủ ở `disputes` (đã ghi "của khiếu nại gần nhất" ở `domain-model.md`).
- Booking chỉ mang một `disputeId` (khiếu nại gần nhất); khiếu nại trước vẫn mở được từ "Khiếu nại của bạn" ở S18.03. Đăng ký vé cũng vậy.
- `amountHeld` trên khiếu nại là bản chụp lúc mở; với khoản bị giữ cả khoản, số này có thể cũ nếu khoản đổi sau đó. Chỉ để hiển thị ở S18.02; tiền lúc xử lý tính lại từ khoản thật.
- Sheet S18.01 vẫn bấm gửi được khi cửa sổ vừa hết mà sheet đang mở; máy chủ trả `deadline_passed` và sheet hiện lỗi.
- Lỗi của trình chọn ảnh trong S18.01 không bắt riêng (giống các màn tải ảnh khác).
- S18.02 dùng `uid ?? ''` khi chưa có người dùng; route nằm sau cổng đăng nhập nên không xảy ra trong thực tế.
- Seed dựng `Dispute`/luồng bằng tay (chữ "Hệ thống" lặp `SYSTEM_NAME`); có thể thêm `buildOpenedDispute`.
- Đóng dấu `depositRefundedAt` một lần lặp lại logic của handler V2; booking đã có `depositRefundedAt` từ lần hoàn trước không nhận thêm `refund_done` cho hoàn khiếu nại.
- Storage không giới hạn số ảnh bằng chứng tải lên (plan chấp nhận; chỉ 5 đường dẫn vào khiếu nại; job dọn hoãn).
- `getSubject` của booking đọc `users/{photographerId}` trong giao dịch (tên, ảnh cho bản chụp): sửa hồ sơ lúc mở/xử lý làm giao dịch chạy lại.
- Staff đọc `disputes` chỉ qua Admin SDK; dashboard S23 cần rule đọc cho staff.
- Thứ tự sinh tài liệu seed đổi (thu nhập sau sự kiện); không test nào phụ thuộc.
- Dòng phụ thẻ khoản ở S18.02 dài hơn mock (phụ đề máy chủ có khung giờ).
- Mục khiếu nại ở S18.03 ẩn im lặng khi đọc lỗi (cố ý, có test).
- `SupportThreadView` sửa `_pendingSeen` trong `build`.
- "Mô tả và 0 ảnh bằng chứng" khi không có ảnh.
- Vuốt đóng sheet S18.01 chỉ ở phần tiêu đề (thân cuộn không đóng).

## 7. Câu hỏi cho chủ dự án

1. **Mất cửa sổ khiếu nại mốc chụp khi thợ giao sớm (Quyết định 2)**: thợ nộp bàn giao thì booking rời `shot`, khách mất cửa sổ khiếu nại buổi chụp dù còn trong 24 giờ sau buổi chụp. Mặc định: giữ như plan.
2. **Ảnh bằng chứng sau khi có kết quả**: S18.02 theo mock không còn hiện "Mô tả & ảnh"; có muốn hai bên vẫn xem lại được không?
3. (Từ plan) luồng ba bên (mặc định có), rút khiếu nại (hoãn), giữ ảnh bằng chứng tới khi xoá tài khoản (job dọn hoãn).
4. ~~Khiếu nại lần hai trên mốc khác~~: đã rút (mục 2.21).

## 8. Viết nhưng không chạy (CI chạy)

- `app_flutter/firebase/rules-test/rules.test.mjs`: `a party reads its dispute`; `a third user cannot get or list a dispute`; `nobody writes disputes from the client`; `a party reads dispute thread messages, a third user cannot`; Storage `dispute evidence: owner uploads a JPEG under their uid, not another's`, `… PNG or a JPEG over 3 MiB is refused (jpegUpTo)`, `… only <id>.jpg file names (letters, digits, _ and -, at most 64) are accepted` (final review S4), `… overwrite refused`, `… a party reads evidence, a third user cannot`, `… owner deletes evidence only while no dispute document exists`. Chỉ `node --check`.
- `app_flutter/firebase/functions/test/integration/dispute.test.ts`: `openDispute then bookingClock leaves the payment disputed; resolveDispute split releases and refunds on the fake gateway` (thêm ở final review: gửi lại cùng quyết định trả kết quả đã lưu; chỉ typecheck).
- Unit test domain, Functions và Flutter đều đã chạy xanh ở từng task (báo cáo task 7–12).

## 9. Thứ tự deploy và công tắc Blaze

1. Firestore rules (khối `disputes`) và hai index `disputes (parties CONTAINS, createdAt DESC)` (S18.03 `mine()`), `disputes (status ASC, createdAt ASC)` (CLI) trước bản app có truy vấn `disputes`. CI tự deploy rules và index khi push vào `develop`.
2. Storage rules (`disputeEvidence`) trước bản app tải ảnh bằng chứng; chỉ chạy tay và cần `BLAZE_ENABLED=true`.
3. Functions (`openDispute` trỏ sang use case mới, `resolveDispute`, `onDisputeWrite`, `onSupportMessageCreated` đã đổi bộ lọc) cùng lúc với bản app: dáng đầu vào cũ của `openDispute` (`{bookingId, reason}`) bị từ chối `invalid_argument`, và bản app trước #142 gọi dáng cũ từ S05.06. Cả hai callable dùng `PAYMENT_CALLABLE_OPTIONS`, cần secret `PAYOUT_ACCOUNT_KEY` (đã ghi ở `FIREBASE-SETUP.md`). Functions chỉ deploy khi `BLAZE_ENABLED=true`; hiện công tắc tắt nên khiếu nại chạy trên emulator (`scripts/backend-local.sh`).
4. Tiền chỉ đi trên đường giả (`FakePaymentGateway`); không có trung gian thật.

## 10. Điểm mở rộng để lại

- **#129 / V2 (tiền)**: `DisputeTx.findSubjectPayment` (booking: `pickSubjectPayment` của domain trên các khoản theo `subjectId`, khoản đã trả còn giữ tiền trước; vé: `registration.paymentId`) là chỗ duy nhất chọn khoản bị giữ; `dispatchDisputeRefund` đã theo V2, trung gian thật chỉ cần thay `PaymentGateway`. `awaiting_account` (#141) không gửi.
- **#152 / #130 (bàn giao)**: `disputeWindow` là luật cửa sổ duy nhất (mốc `shoot`/`delivery`); `DisputeOrigin.deliveryCheck` + `/b/:id/dispute?from=delivery` là điểm vào của S05.06; khiếu nại do thợ mở sau "hết lượt sửa" đi qua cùng use case với `openedBy: 'provider'` (chưa có).
- **#207 (S05.08 huỷ phần bàn giao khi trễ)**: #207 chỉ nhận booking `shot` (Quyết định 1 của nó), còn khiếu nại mốc bàn giao chỉ có ở `approved`, nên hai luồng không gặp nhau; khiếu nại mốc chụp đang mở (`escrowStatus: disputed`) vẫn bị #207 từ chối `conflict` (Quyết định 6). Plan #207 viết trên code trước #142: `open_dispute.ts`, `canCustomerDispute` và `BookingRepository.openDispute` không còn. Booking có mốc ở `completed` đã là `not_eligible` trong `disputeWindow` (không phải `conflict`; bỏ Quyết định 11 của #207 (thêm `conflict` cho `completed` vào `open_dispute.ts` đã xoá) vì `disputeWindow` đã trả `not_eligible`; test Task 2 của #207 về khiếu nại booking `completed` phải mong `not_eligible`). Quyết định 16 của #207 áp vào `bookingDisputeClosesAt` (`features/disputes/dispute_entry.dart`).
- **#83 / S23.01, S23.06**: dashboard gọi `resolveDispute` và `staffReply`; cần rule đọc `disputes` cho staff.
- **Phase 2 (#90)**: `services/api` không có khiếu nại; DDL đích ở `relational-schema.md` mục 2.5a.

## 11. Seed

`disputes/seed-dispute-lan-an` (mở, trên `seed-booking-disputed`, `payment.dispute {reason: photos_missing, disputeId, milestone: null, prevEscrowStatus: held}`), luồng `dispute_seed-dispute-lan-an` (dòng hệ thống, mô tả của Lan có `opening`, câu hỏi của `seed-staff-admin`, trả lời của An; `awaitingStaff: true`); `seed-booking-completed-window` (hoàn thành 2 giờ trước khi seed, tiền giữ) và vé `seed-registration-lan-past-paid` của `seed-event-an-past-workshop` (kết thúc 3 giờ trước, 250 000 ₫, tiền giữ) để thử S18.01. Hệ quả: `completedCount` của An 3 → 4, tiền đang giữ 7,5 M → 9 M → 9,25 M (có vé); bốn tin của luồng seed được ghi bằng Admin SDK nên `onSupportMessageCreated` gửi thông báo sau khi seed (chỉ emulator). Chi tiết và ví dụ CLI: `app_flutter/firebase/functions/seed/README.md` mục "Disputes".

## 12. Hoãn theo plan

- Trung gian thanh toán thật, hoàn và chi trả thật (#129, payments spec §10–11); khiếu nại chạy trên cổng giả.
- Dashboard staff S23.01 (hàng đợi khiếu nại) và S23.06 (hộp thư hỗ trợ), phase 1.5 (#83); phase 1 dùng `resolveDispute` + CLI.
- Khiếu nại do thợ mở sau "hết lượt sửa" (#130).
- Rút khiếu nại; job dọn ảnh bằng chứng; ảnh trong chat hỗ trợ; trạng thái "đang xem xét" riêng của staff.
- FAQ "Chụp ngay" (S13); `services/api` (đã chuyển sang repo booking-be ở #286) và backend Go phase 2 (#90).
- Sự kiện phân tích (chưa có lớp phân tích).

## 13. Final review

Review toàn nhánh (base 4b24b14a → `59efdf59`), ba phần: máy chủ và app "sẵn sàng merge" kèm minor gộp vào fix wave; tài liệu có ba mục Important (D1–D3).

**Đã sửa (fix wave)**

| Mục | Nội dung | Commit |
|---|---|---|
| S1 | `resolveDispute` gửi lại cùng quyết định của cùng staff trả kết quả đã lưu thay vì `conflict` (mục 2.27); test domain, callable, CLI, integration (viết, không chạy) | `8171a3c8` |
| S2 | CLI `disputes resolve`: lỗi gửi hoàn sau khi ghi quyết định in "decision saved; refund left pending for re-send", thoát 2 (mục 2.28) | `8171a3c8` |
| S3 | `pickSubjectPayment` vào domain, store bộ nhớ dùng chung (mục 2.29); test khoản lạc đã trả | `8171a3c8` |
| S4 | `storage.rules`: tên tệp bằng chứng `^[A-Za-z0-9_-]{1,64}[.]jpg$` (mục 2.30); rules test viết, không chạy | `8171a3c8` |
| A1 | S05.02 không hiện dải khiếu nại cho thành viên studio được giao việc (không thuộc `parties`, S18.02 sẽ "Không tìm thấy") | `2cea7aa1` |
| A2 | S11.04 theo `nowTickerProvider` (1 phút): "Báo vấn đề" hiện lúc sự kiện kết thúc và ẩn sau 24 giờ khi tab vẫn mở | `2cea7aa1` |
| A3 | Hàng khiếu nại ở S18.03 dùng `AppRadius.sheet` | `2cea7aa1` |
| A4 | `FakeDisputeRepository` lấy `createdAt` từ đồng hồ giả của world | `2cea7aa1` |
| D1 | Ghi chú bàn giao cho #207 viết lại (mục 10) | commit tài liệu này |
| D2 | Hoãn: `payment.dispute` chỉ của khiếu nại gần nhất, booking một `disputeId` (mục 6); `domain-model.md` ghi rõ | commit tài liệu này |
| D3 | Bốn dòng sửa trong plan, mỗi dòng trỏ về mục 4 | commit tài liệu này |
| D4 | `screens/booking.md`: S05.06 "Báo vấn đề với ảnh gốc" → `/b/:id/dispute?from=delivery`; S05.02 thêm dòng khiếu nại trỏ sang `disputes-help.md` | commit tài liệu này |
| D5 | `shared-components.md`: `EscrowNotice` có bốn tham số mới (cả `icon`) | commit tài liệu này |
| D6 | Điền mục này, hash Task 13 | commit tài liệu này |

**Test đã chạy sau fix wave**: domain `npm test` 2211/2211 + `lint` sạch; Functions `npm test` 819/819, `build`, `lint` sạch; Flutter từng thư mục `test/features/booking` 325, `events` 151, `help` 15, `disputes` 43 đều xanh; `dart run tool/affected_test.dart origin/develop --run` 4926 xanh (42 bỏ qua có sẵn); `flutter analyze lib test` sạch. Rules test và integration test: viết, không chạy (mục 8).

**Giữ lại có lý do**: các mục "Ứng viên FINAL WAVE" và "Hoãn" ở mục 6 (final review đồng ý hoãn), gồm đề xuất issue tiếp theo: chuyển lần đọc khoản thanh toán của `commit_transition` vào trong giao dịch.

PR: (điền khi mở). CI chạy rules test và integration test của mục 8.
