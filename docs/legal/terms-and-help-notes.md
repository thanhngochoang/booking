# Ghi chú cho Điều khoản sử dụng và Trợ giúp

Danh sách các quy định sản phẩm phải có trong **Điều khoản sử dụng** (văn bản pháp lý, chưa viết) và trong **S18.03 Trợ giúp** (câu hỏi thường gặp tĩnh, `/help`). Mỗi mục ghi nguồn (spec) để khi viết hai văn bản đó chỉ cần chép và diễn đạt lại cho người dùng. Khi một spec đổi quy định, sửa mục tương ứng ở đây.

Trạng thái: **ĐK** = cần trong điều khoản, **FAQ** = cần trong trợ giúp.

## Thanh toán và tiền giữ

| # | Quy định | Nguồn | Dùng ở |
|---|---|---|---|
| P1 | Khách trả **100% giá khi đặt** (gói, báo giá, Chụp ngay). Tiền **được giữ trên app**, chưa chuyển cho thợ ảnh. | provider-types 2026-10-05 §4.1 | ĐK, FAQ |
| P2 | Tiền chuyển cho thợ/studio theo **2 mốc**, mặc định 50/50: mốc 1 sau buổi chụp (bấm "Đã chụp xong" hoặc tự động 24 giờ sau giờ kết thúc) và hết 24 giờ khiếu nại; mốc 2 sau khi khách **đồng ý ảnh** và hết **48 giờ kiểm tra** bộ ảnh gốc. | bàn giao 2026-10-06 §4 | ĐK, FAQ |
| P3 | Bàn giao hai lớp: thợ/studio gửi **ảnh mẫu có watermark** (3–20 ảnh) trước; **link bộ ảnh gốc bị che** và chỉ mở khi khách bấm "Đồng ý ảnh". Khách im lặng **3 ngày** kể từ lần gửi ảnh mẫu gần nhất thì hệ thống tự đồng ý. | bàn giao §2, §4 | ĐK, FAQ |
| P4 | Sau khi link mở, khách có **48 giờ** để kiểm tra bộ ảnh gốc (thiếu ảnh, khác ảnh mẫu, link hỏng) và bấm "Báo vấn đề"; khi đó tiền mốc 2 tiếp tục được giữ tới khi có kết quả khiếu nại. App chỉ che link trong app; nếu thợ/studio tự gửi link qua kênh khác trước khi khách đồng ý là lựa chọn của họ. | bàn giao §4, §7 | ĐK, FAQ |
| P5 | Hai bên trao đổi màu, chỉnh sửa, photoshop trên ảnh mẫu. Số vòng sửa miễn phí theo gói/báo giá (0–5); hết lượt thì khách đồng ý, xin thêm vòng (thợ/studio có quyền cho hoặc không), hoặc mở khiếu nại để staff phân xử. | bàn giao §2 B3 | ĐK, FAQ |
| P6 | Thợ giao trễ quá số ngày đã hẹn: khách được "Huỷ phần bàn giao", **hoàn 100% mốc 2**; thợ giữ mốc 1. | provider-types §4.1 | ĐK, FAQ |
| P7 | Huỷ trước buổi chụp: ≥ 48 giờ hoàn 100%, 24–48 giờ hoàn 50%, < 24 giờ không hoàn; tính trên toàn bộ tiền đã trả. Thợ huỷ: khách hoàn 100%. | provider-types §4.3 | ĐK, FAQ |
| P8 | Khiếu nại mở được trong cửa sổ của từng mốc; trong lúc khiếu nại, tiền tiếp tục được giữ tới khi có kết quả (thả, hoàn hoặc chia). | spec chính S18; provider-types §4.1 | ĐK, FAQ |
| P9 | Vì sao trả trước 100%: nửa sau tiền không đến tay thợ cho tới khi bạn đồng ý ảnh mẫu và kiểm xong bộ ảnh gốc; có lỗi thì được hoàn qua app. Thợ cũng yên tâm không bị quỵt, nên nhận lịch nhanh hơn. | quyết định 2026-10-06 (chọn giữ trả trước 100%, không dùng "cọc + trả nốt sau khi nhận ảnh") | FAQ |

## Liên hệ

| # | Quy định | Nguồn | Dùng ở |
|---|---|---|---|
| C1 | Gọi, Zalo, WhatsApp chỉ mở sau khi đã thanh toán; trước đó chỉ nhắn tin hỏi trong app. Khách cần số điện thoại để đặt lịch. Số điện thoại không hiện công khai. | spec chính §liên hệ | ĐK, FAQ |

## Đánh giá

| # | Quy định | Nguồn | Dùng ở |
|---|---|---|---|
| R1 | Đánh giá bằng **cà chua** (hài lòng) hoặc **gạch** (không hài lòng), bấm 1–10 lần để nói mức độ; con số công khai là % cà chua. | tomato-brick 2026-10-06 | FAQ |
| R2 | Mỗi đối tượng một đánh giá cho mỗi booking, mở ngay khi khách đồng ý ảnh (link ảnh gốc mở); gửi rồi không sửa, không xoá. | tomato-brick §3.1, §5; bàn giao B6 | ĐK, FAQ |
| R3 | Gạch hiện công khai và phải kèm ít nhất một lý do; nội dung đánh giá 10–1000 ký tự. | tomato-brick §3.1 | ĐK, FAQ |
| R4 | Booking với Studio: khách đánh giá **cả thợ được giao và studio**, mỗi bên một bộ cà chua/gạch và nhận xét riêng, bắt buộc cả hai; đánh giá thợ tính vào hồ sơ cá nhân của thợ. | studio 2026-10-06 §6 | FAQ |

## Studio

| # | Quy định | Nguồn | Dùng ở |
|---|---|---|---|
| S1 | Đặt với Studio: studio chốt giá rồi giao một thợ thành viên; studio **phải báo thợ chụp chậm nhất 24 giờ trước buổi chụp**. | studio 2026-10-06 §5.2 | ĐK, FAQ |
| S2 | Khách xem hồ sơ thợ được giao và được **xin đổi thợ 1 lần**; studio trả lời trong 6 giờ. Studio quá hạn giao thợ, từ chối/không trả lời yêu cầu đổi, hoặc tự đổi thợ khi còn dưới 24 giờ → khách được **huỷ và hoàn 100%**. | studio §5.3, §5.4 | ĐK, FAQ |
| S3 | Booking studio: **studio bàn giao ảnh** và chịu hạn giao ảnh; tiền trả cho studio theo các mốc ở P2; studio tự chia với thợ, app không can thiệp. | studio §5.1, §5.6 | ĐK |
| S4 | Thợ thuộc tối đa một studio một lúc, vẫn nhận booking cá nhân. Vào studio cần hai bên đồng ý (lời mời hết hạn sau 7 ngày); rời hoặc bị bỏ thì 7 ngày sau mới vào studio khác; không rời/bỏ được khi còn việc được giao chưa xong. Studio chưa xác minh tối đa 3 thợ, đã xác minh tối đa 30. | studio §3 | ĐK (điều khoản cho thợ và studio) |
| S5 | Số điện thoại, Zalo, WhatsApp của thợ được giao chỉ mở cho khách sau khi giao thợ và đã thanh toán; đổi thợ thì đóng với thợ cũ. | studio §5.7 | ĐK, FAQ |
