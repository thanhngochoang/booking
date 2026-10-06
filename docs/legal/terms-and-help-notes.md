# Ghi chú cho Điều khoản sử dụng và Trợ giúp

Danh sách các quy định sản phẩm phải có trong **Điều khoản sử dụng** (văn bản pháp lý, chưa viết) và trong **S18.03 Trợ giúp** (câu hỏi thường gặp tĩnh, `/help`). Mỗi mục ghi nguồn (spec) để khi viết hai văn bản đó chỉ cần chép và diễn đạt lại cho người dùng. Khi một spec đổi quy định, sửa mục tương ứng ở đây.

Trạng thái: **ĐK** = cần trong điều khoản, **FAQ** = cần trong trợ giúp.

## Thanh toán và tiền giữ

| # | Quy định | Nguồn | Dùng ở |
|---|---|---|---|
| P1 | Khách trả **100% giá khi đặt** (gói, báo giá, Chụp ngay). Tiền **được giữ trên app**, chưa chuyển cho thợ ảnh. | provider-types 2026-10-05 §4.1 | ĐK, FAQ |
| P2 | Tiền chuyển cho thợ theo **2 mốc**, mặc định 50/50: mốc 1 sau buổi chụp (thợ bấm "Đã chụp xong" hoặc tự động 24 giờ sau giờ kết thúc) và hết 24 giờ khiếu nại; mốc 2 khi khách **duyệt bàn giao ảnh**. | provider-types §4.1 | ĐK, FAQ |
| P3 | Khách không phản hồi bàn giao trong **3 ngày** thì hệ thống **tự duyệt** và chuyển mốc 2. | provider-types §4.1 | ĐK, FAQ |
| P4 | Link bộ ảnh hiện cho khách ngay khi thợ bàn giao, kèm tối đa 10 ảnh xem trước lưu trên app làm bằng chứng. | provider-types §4.1; quyết định 2026-10-06 | FAQ |
| P5 | Khách được yêu cầu chỉnh sửa theo số lượt ghi trong gói/báo giá (0–5); hết lượt chỉ còn Duyệt hoặc Khiếu nại. | provider-types §4.1 | ĐK, FAQ |
| P6 | Thợ giao trễ quá số ngày đã hẹn: khách được "Huỷ phần bàn giao", **hoàn 100% mốc 2**; thợ giữ mốc 1. | provider-types §4.1 | ĐK, FAQ |
| P7 | Huỷ trước buổi chụp: ≥ 48 giờ hoàn 100%, 24–48 giờ hoàn 50%, < 24 giờ không hoàn; tính trên toàn bộ tiền đã trả. Thợ huỷ: khách hoàn 100%. | provider-types §4.3 | ĐK, FAQ |
| P8 | Khiếu nại mở được trong cửa sổ của từng mốc; trong lúc khiếu nại, tiền tiếp tục được giữ tới khi có kết quả (thả, hoàn hoặc chia). | spec chính S18; provider-types §4.1 | ĐK, FAQ |
| P9 | Vì sao trả trước 100%: tiền không đến tay thợ cho tới khi bạn nhận và duyệt ảnh; có lỗi thì được hoàn qua app. Thợ cũng yên tâm không bị quỵt, nên nhận lịch nhanh hơn. | quyết định 2026-10-06 (chọn giữ trả trước 100%, không dùng "cọc + trả nốt sau khi nhận ảnh") | FAQ |

## Liên hệ

| # | Quy định | Nguồn | Dùng ở |
|---|---|---|---|
| C1 | Gọi, Zalo, WhatsApp chỉ mở sau khi đã thanh toán; trước đó chỉ nhắn tin hỏi trong app. Khách cần số điện thoại để đặt lịch. Số điện thoại không hiện công khai. | spec chính §liên hệ | ĐK, FAQ |

## Đánh giá

| # | Quy định | Nguồn | Dùng ở |
|---|---|---|---|
| R1 | Đánh giá bằng **cà chua** (hài lòng) hoặc **gạch** (không hài lòng), bấm 1–10 lần để nói mức độ; con số công khai là % cà chua. | tomato-brick 2026-10-06 | FAQ |
| R2 | Mỗi booking một đánh giá, mở sau khi duyệt bàn giao; gửi rồi không sửa, không xoá. | tomato-brick §3.1, §5.4 | ĐK, FAQ |
| R3 | Gạch hiện công khai và phải kèm ít nhất một lý do; nội dung đánh giá 10–1000 ký tự. | tomato-brick §3.1 | ĐK, FAQ |
| R4 | Booking với Studio: khách đánh giá **cả thợ được giao và studio**, mỗi bên một nhận xét riêng; đánh giá thợ tính vào hồ sơ cá nhân của thợ. | studio (đang thiết kế) | FAQ |

## Studio (đang thiết kế, cập nhật khi spec Studio được duyệt)

| # | Quy định | Nguồn | Dùng ở |
|---|---|---|---|
| S1 | Đặt với Studio: studio chốt giá rồi giao một thợ thành viên; studio **phải báo thợ chụp chậm nhất 24 giờ trước buổi chụp**. | studio | ĐK, FAQ |
| S2 | Khách xem hồ sơ thợ được giao và được **xin đổi thợ 1 lần**. Studio quá hạn giao thợ hoặc từ chối đổi → khách được **huỷ và hoàn 100%**. | studio | ĐK, FAQ |
| S3 | Tiền của booking studio trả cho studio theo các mốc ở P2; studio tự chia với thợ, app không can thiệp. | studio | ĐK |
| S4 | Thợ thuộc tối đa một studio một lúc, vẫn nhận booking cá nhân. Vào studio cần hai bên đồng ý; rời hoặc bị bỏ thì chờ 7 ngày mới vào lại; không rời/bỏ được khi còn việc được giao chưa xong. | studio | ĐK (điều khoản cho thợ và studio) |
