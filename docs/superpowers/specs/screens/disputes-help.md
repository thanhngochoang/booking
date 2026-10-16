# S18 · Khiếu nại & hỗ trợ

Tài liệu chi tiết cho nhóm màn hình S18:
- S18.01 Mở khiếu nại (sheet)
- S18.02 Chi tiết khiếu nại
- S18.03 Trợ giúp & chat hỗ trợ

---

## S18.01 · Mở khiếu nại (sheet)

- **Thông tin**: `ScreenCodes.openDispute`, route `/b/:id/dispute` (trên S05.02; query `?from=delivery` cho trường hợp kiểm tra bàn giao) hoặc sheet trên S11.04 vé sự kiện. Vai trò: khách hàng. Trạng thái: Chưa có (#142).
- **Mục đích**: Khách hàng mở khiếu nại trong cửa sổ cho phép (sau buổi chụp 24h hoặc kiểm tra bộ ảnh gốc 48h; vé sự kiện có phí trong 24h sau khi sự kiện kết thúc).
- **Điểm vào → điểm ra**: Vào từ nút "Báo vấn đề" ở S05.02 hoặc S11.04; sau khi gửi chuyển tới S18.02 chi tiết khiếu nại.
- **Bố cục**:
  - Tiêu đề: "Báo vấn đề" (hoặc "Báo vấn đề với ảnh gốc").
  - Thanh đếm thời gian: "Còn {hours} giờ để báo vấn đề...".
  - Chọn lý do: danh sách lý do theo loại chủ thể (không đến, không đúng thoả thuận, thiếu ảnh, khác ảnh mẫu, link hỏng, sự kiện không diễn ra, khác mô tả, khác).
  - Nhập mô tả (10–1000 ký tự).
  - Đính kèm tối đa 5 ảnh bằng chứng (`disputeEvidence/{uid}/{disputeId}/...`).
  - Nút chính: "Gửi khiếu nại".
- **Dữ liệu**: Gọi callable `openDispute`. Tiền liên quan bị đóng băng (`disputed`).
- **Trạng thái**: Tải ảnh bằng chứng, gửi khiếu nại, lỗi quá hạn (`deadline_passed`), lỗi trùng (`conflict`), không đủ điều kiện (`not_eligible`).

---

## S18.02 · Chi tiết khiếu nại

- **Thông tin**: `ScreenCodes.disputeDetail`, route `/disputes/:id`. Vai trò: Khách hàng, bên cung cấp (thợ ảnh, studio, chủ sự kiện), nhân viên hỗ trợ. Trạng thái: Chưa có (#142).
- **Mục đích**: Theo dõi trạng thái khiếu nại, tiền đang tạm giữ, trao đổi 3 bên và xem kết quả giải quyết.
- **Điểm vào → điểm ra**: Vào từ S18.01, banner "Đang khiếu nại" ở S05.02, thông báo, hoặc mục "Khiếu nại của bạn" ở S18.03.
- **Bố cục**:
  - Tiêu đề: "Khiếu nại #{code}".
  - Badge trạng thái: "Đang xem xét" / "Đã xử lý".
  - Thẻ tiền đang tạm giữ và tiến trình các bước.
  - Khối mô tả & ảnh bằng chứng.
  - Khối trao đổi (chat 3 bên qua `SupportThreadView`).
  - Khối kết quả (nếu đã giải quyết: thả / hoàn / chia).
- **Dữ liệu**: Đọc `disputes/{id}` và stream `support_threads/dispute_{id}/messages`.

---

## S18.03 · Trợ giúp & chat hỗ trợ

- **Thông tin**: `ScreenCodes.help`, route `/help` và `/help/chat`. Vai trò: Tất cả người dùng đã đăng nhập. Trạng thái: Đã có (#204).
- **Mục đích**: Xem câu hỏi thường gặp (FAQ) theo chủ đề và chat trực tiếp với hộp thư hỗ trợ (`support_threads/help_{uid}`).
- **Điểm vào → điểm ra**: Vào từ menu Cài đặt S09.02 (mục "Hỗ trợ" -> "Trợ giúp"); nút "Liên hệ hỗ trợ" chuyển sang `/help/chat`.
- **Bố cục**:
  - Khối "Khiếu nại của bạn" (chỉ hiện khi có khiếu nại đang mở hoặc gần đây, do #142 bổ sung).
  - Khối "Câu hỏi thường gặp": các chip chủ đề (Thanh toán, Huỷ & hoàn tiền, Bàn giao ảnh, Khiếu nại, Liên hệ, Đánh giá, Dành cho thợ ảnh). Mỗi câu hỏi là một hàng bấm để mở rộng câu trả lời.
  - Đáy màn hình: Nút "Liên hệ hỗ trợ" kèm dòng "Email hỗ trợ: {email}" (nếu cấu hình `SUPPORT_EMAIL`).
- **Màn chat hỗ trợ (`/help/chat`)**:
  - Tiêu đề: "Hỗ trợ".
  - Ghi chú bảo mật: "Chỉ bạn và đội hỗ trợ xem được cuộc trò chuyện này. Đừng gửi mật khẩu hay mã OTP."
  - Danh sách tin nhắn (`SupportThreadView`).
  - Thanh nhập tin nhắn ở đáy: "Nhắn cho hỗ trợ…".
- **Dữ liệu**: Stream tin nhắn `support_threads/help_{uid}/messages`; gửi tin nhắn qua callable `sendSupportMessage`.
