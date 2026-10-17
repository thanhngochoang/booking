# S20 · Báo cáo & chặn

Màn: S20.01 (Báo cáo sheet), S20.02 (Người đã chặn), các trạng thái đã chặn (S03.01, S02.02, S07.01, S05.02) và menu "…" chia sẻ / báo cáo / chặn. Quy ước chung ở [README.md](README.md). Widget ở [../components/shared-components.md](../components/shared-components.md).

---

## S20.01 · Báo cáo (sheet)

- **Thông tin**: `— (sheet)` · cả hai vai trò · sub‑project 6 · **Đã làm** (#144)
- **Mục đích**: Báo cáo người dùng, bài viết, tin nhắn hoặc sự kiện với lý do cố định, mô tả tuỳ chọn và tuỳ chọn chặn luôn đối tượng.
- **Điểm vào → ra**:
  - Menu "…" trên hồ sơ nhiếp ảnh gia (S03.01), bài viết (S02.02, S11.05), tin nhắn (nhấn giữ ở S07.01, S11.06), sự kiện (S11.02), portfolio album (S24.01).
  - Gửi xong đóng sheet, hiện thông báo SnackBar.
- **Bố cục** (theo mock `#S20.01` và `#S20.01-message`):
  - Tiêu đề hàng trên: "Báo cáo {name}" / "Báo cáo bài viết" / "Báo cáo tin nhắn" / "Báo cáo sự kiện" kèm nút đóng (icon `close`).
  - Dòng ghi chú ẩn danh: "Người bị báo cáo không biết ai đã báo cáo."
  - Với tin nhắn: thẻ trích dẫn (`format_quote`, tên người gửi, nội dung tin nhắn bị báo cáo).
  - Tiêu đề nhóm: "Vì sao bạn báo cáo?"
  - Danh sách 7 lý do (`ReasonPicker` dạng radio):
    1. Spam hoặc quảng cáo (`spam`)
    2. Lừa đảo, đòi chuyển tiền ngoài ứng dụng (`scam`)
    3. Quấy rối hoặc xúc phạm (`harassment`)
    4. Nội dung nhạy cảm, không phù hợp (`inappropriate`)
    5. Ảnh lấy cắp, vi phạm bản quyền (`stolen_photos`)
    6. Giả mạo người khác (`impersonation`)
    7. Lý do khác (`other`)
  - Ô nhập: "Mô tả thêm (tuỳ chọn)" (bắt buộc ≥ 10 ký tự nếu chọn "Lý do khác", tối đa 500 ký tự).
  - Hộp kiểm "Chặn {name}" kèm giải thích "Hai bên không thấy bài của nhau, không nhắn tin hay đặt lịch với nhau." (ẩn với sự kiện do nền tảng tổ chức hoặc nội dung của chính mình).
  - Nút chính đáy: `AppButton.primary` "Gửi báo cáo" (52dp).
- **Dữ liệu**: `ReportController`, gọi callable `submitReport`.
- **Trạng thái**:
  - Mặc định: chưa chọn lý do, nút "Gửi báo cáo" vô hiệu.
  - Đang gửi: nút hiển thị loading spinner.
  - Thành công: SnackBar "Đã gửi báo cáo. Cảm ơn bạn." (hoặc "Đã gửi báo cáo và chặn {name}.").
  - Trùng lặp: "Bạn đã báo cáo nội dung này rồi."
  - Vượt hạn mức: "Bạn đã gửi nhiều báo cáo hôm nay. Thử lại ngày mai." (tối đa 20 báo cáo/ngày).
- **Tương tác**:
  - Chọn lý do khác yêu cầu nhập tối thiểu 10 ký tự trước khi nút gửi sáng.
  - Tích chọn "Chặn {name}" sẽ thực hiện cả việc báo cáo và chặn trong cùng 1 thao tác.
- **Chuỗi tiếng Việt** (trong `app_vi.arb`):
  - `reportTitleUser`, `reportTitlePost`, `reportTitleMessage`, `reportTitleEvent`, `reportAnonymous`, `reportReasonTitle`, `reportReasonSpam`, `reportReasonScam`, `reportReasonHarassment`, `reportReasonInappropriate`, `reportReasonStolen`, `reportReasonImpersonation`, `reportReasonOther`, `reportTextLabel`, `reportTextRequired`, `reportBlockAlso`, `reportBlockAlsoBody`, `reportSubmit`, `reportSent`, `reportSentBlocked`, `reportDuplicate`, `reportLimit`, `reportFailed`.
- **Phân tích**: `screen_view{code: "s20_01"}`.
- **Chấp nhận**: Báo cáo gửi đúng mã lý do và bản chụp snapshot; lặp lại báo cáo không tạo bản ghi mới; vừa màn hình 320dp ở cỡ chữ 1.3x.

---

## S20.02 · Người đã chặn

- **Thông tin**: `/settings/blocked` · cả hai vai trò · sub‑project 6 · **Đã làm** (#144)
- **Mục đích**: Xem danh sách những người mình đã chặn và bỏ chặn khi muốn kết nối lại.
- **Điểm vào → ra**: Cài đặt (S09.02) → "Người đã chặn". Nút bỏ chặn mở dialog / sheet xác nhận.
- **Bố cục** (theo mock `#S20.02`):
  - Thanh tiêu đề: nút Back, tiêu đề "Người đã chặn".
  - Ghi chú đầu danh sách: "Người bạn chặn không thấy bài của bạn, không nhắn tin hay đặt lịch với bạn. Họ không nhận thông báo."
  - Danh sách người bị chặn: Avatar tròn, tên hiển thị, ngày chặn "Chặn {date}", nút viền nhỏ "Bỏ chặn".
- **Dữ liệu**: `BlockedUsersController` (`blockedUsersProvider`), gọi callable `unblockUser`.
- **Trạng thái**:
  - Loading: skeleton danh sách.
  - Empty: "Bạn chưa chặn ai" / "Chặn từ menu … trên hồ sơ, bài viết hoặc tin nhắn."
  - Lỗi: thông báo lỗi kèm "Thử lại".
- **Tương tác**:
  - Bấm "Bỏ chặn": mở xác nhận `confirmUnblock` ("Bỏ chặn {name}?", nội dung "Hai bên lại thấy bài của nhau, nhắn tin và đặt lịch được."). Xác nhận bỏ chặn xong hàng biến mất khỏi danh sách, hiện thông báo "Đã bỏ chặn {name}".
- **Chuỗi tiếng Việt** (trong `app_vi.arb`):
  - `blockedTitle`, `blockedNote`, `blockedSince`, `blockedUnblock`, `blockedEmptyTitle`, `blockedEmptyBody`, `settingsBlocked`, `settingsBlockedBody`, `unblockConfirmTitle`, `unblockConfirmBody`, `unblockConfirm`, `unblockKeep`, `unblockDone`.
- **Phân tích**: `screen_view{code: "s20_02"}`.
- **Chấp nhận**: Danh sách hiển thị người mới chặn lên trước; bỏ chặn cập nhật danh sách ngay lập tức; không tràn màn hình 320dp cỡ chữ 1.3x.

---

## Trạng thái đã chặn & Menu "…" dùng chung

- **Menu "…" dùng chung (`showSafetyMenu`)**:
  - Hồ sơ S03.01: "Chia sẻ hồ sơ", "Báo cáo", "Chặn {name}" / "Bỏ chặn {name}".
  - Bài viết S02.02, S11.05: "Báo cáo bài viết", "Chặn {name}".
  - Tin nhắn S07.01, S11.06: "Báo cáo tin nhắn", "Chặn {name}".
  - Sự kiện S11.02: "Báo cáo sự kiện".
  - Album S24.01: "Báo cáo {name}".
- **Màn hình khi đã chặn**:
  - Hồ sơ S03.01:
    - Khi bạn chặn họ: "Bạn đã chặn {name}" / "Bỏ chặn để xem hồ sơ, nhắn tin và đặt lịch." kèm nút "Bỏ chặn".
    - Khi họ chặn bạn: "Không xem được hồ sơ này" / "Hồ sơ này không hiển thị với bạn."
  - Bài viết S02.02: "Không xem được bài này" / "Bài này không hiển thị với bạn."
  - Trò chuyện S07.01: Khung nhập tin nhắn bị vô hiệu hoá, hiển thị "Bạn đã chặn {name}. Bỏ chặn để nhắn tin." kèm liên kết "Bỏ chặn" (nếu bạn chặn) hoặc "Không gửi được tin nhắn trong cuộc trò chuyện này." (nếu họ chặn).
  - Chi tiết booking S05.02: Ẩn nút "Nhắn tin" và liên hệ ngoài, hiển thị lưu ý "Hai bên đã chặn nhau. Cần trao đổi về buổi chụp, hãy liên hệ hỗ trợ."
