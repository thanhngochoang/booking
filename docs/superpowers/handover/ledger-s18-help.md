# Ledger: S18.03 Trợ giúp, FAQ và Chat Hỗ trợ (#204)

Tài liệu bàn giao và ghi nhận quyết định kỹ thuật cho nhánh `plan/204-s18-help` (Issue #204).

## 1. Ranh giới triển khai (#204 vs #142)
Kế hoạch `docs/superpowers/plans/2026-10-07-s18-disputes-help.md` gộp cả hai mảng:
- **#204 (nhánh hiện tại)**: Triển khai toàn bộ nền tảng trợ giúp S18.03:
  - Cấu trúc `support_threads/help_{uid}` và tin nhắn subcollection `messages`.
  - Use case `sendSupportMessage` (phía người dùng và staff), tự động khởi tạo thread nếu chưa có, giới hạn tốc độ gửi (≤ 5 tin trong 30 giây).
  - Quy tắc bảo mật Firestore (`firestore.rules`): người dùng chỉ đọc tin của chính họ trong `help_{uid}`, tin nhắn chỉ đọc/ghi thông qua Cloud Functions callable `sendSupportMessage`.
  - Notification trigger `onSupportMessageCreated`: gửi in-app notification `support_reply` cho người dùng khi staff trả lời; ghi nhận và log khi người dùng gửi tin cho staff.
  - Staff CLI `npm run support` (`tools/support.ts`): liệt kê danh sách thread cần hỗ trợ (`list`), xem hội thoại (`show`), và gửi tin nhắn trả lời (`reply`).
  - Frontend Flutter:
    - Data layer: `SupportThread`, `SupportMessage`, `SupportRepository`, `FirestoreSupportRepository`.
    - Màn hình Trợ giúp `HelpScreen` (`/help`): FAQ theo chủ đề, danh mục collapsible câu hỏi & câu trả lời theo đúng câu chữ bản đặc tả, nút "Liên hệ hỗ trợ" chuyển sang `/help/chat`, email liên hệ hỗ trợ.
    - Màn hình Chat hỗ trợ `SupportChatScreen` (`/help/chat`): Bố cục bảo mật, ghi chú quyền riêng tư, danh sách tin nhắn `SupportThreadView`, composer gửi tin.
    - Điểm vào từ menu Cài đặt (`SettingsScreen` S09.02): nhóm "Hỗ trợ" -> hàng "Trợ giúp".
- **#142 (triển khai tiếp theo)**:
  - Mở khiếu nại S18.01 (`openDispute`).
  - Chi tiết khiếu nại S18.02 (`/disputes/:id`), thread `support_threads/dispute_{id}`.
  - Mục "Khiếu nại của bạn" trên màn hình Trợ giúp `HelpScreen` S18.03 (`myDisputesProvider`).

## 2. Rulings & Quyết định kỹ thuật
1. **Nền tảng luồng hội thoại hợp nhất (`support_threads`)**:
   Hộp thư hỗ trợ 1-1 (`help_{uid}`) và các luồng tranh chấp/khiếu nại (`dispute_{id}`) chia sẻ chung mô hình `SupportThread` và subcollection `messages`.
2. **Quyền riêng tư & bảo mật**:
   - `support_threads/{threadId}/messages` không cho phép client ghi trực tiếp. Mọi tin nhắn phải đi qua callable `sendSupportMessage` để kiểm tra quyền và xác thực danh tính.
   - Tin nhắn từ staff có `senderRole: 'staff'`, hiển thị nhãn "Hỗ trợ".
3. **Thứ tự nhóm cài đặt S09.02**:
   Nhóm "Hỗ trợ" (`support`) được bố trí sau `notifications`/`paymentsData` và trước `signOut`, đảm bảo thứ tự `settingsGroupOrder` nhất quán.
4. **FAQ tĩnh và câu chữ đồng bộ**:
   Toàn bộ câu hỏi & câu trả lời FAQ được định nghĩa tập trung ở `HelpFaq` và `app_vi.arb`, trích xuất trực tiếp từ các quy định pháp lý và điều khoản sản phẩm (P1-P13, V1-V5, C1, R1-R4).

## 3. Extension Points cho Issue #142
- Nhánh `kind: 'dispute'` trong `sendSupportMessage` (Cloud Functions) đã để sẵn hook kiểm tra `getDispute(thread.disputeId)` và ủy quyền cho các bên tranh chấp.
- Widget `SupportThreadView` được thiết kế linh hoạt, hỗ trợ tái sử dụng trực tiếp trên màn hình chi tiết khiếu nại S18.02.
- Màn hình `HelpScreen` đã chuẩn bị sẵn vùng hiển thị danh sách khiếu nại đang mở ("Khiếu nại của bạn"), chỉ cần kết nối với `myDisputesProvider` từ #142.
