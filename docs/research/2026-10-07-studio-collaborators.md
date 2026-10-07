# Nghiên cứu: S27 "Studio tuyển thợ" và hình thức cộng tác viên

Ngày: 2026-10-07 · Phạm vi: chỉ đọc repo, tra cứu web. Đây là nghiên cứu cho quyết định sản phẩm, **không phải tư vấn pháp lý**; mọi mục đánh dấu **[CHƯA XÁC NHẬN]** cần luật sư/kế toán kiểm tra trước khi viết điều khoản.

Ngữ cảnh đã đọc: `studio-members-design` (S26: T1–T12, chống spam, giao thợ, đánh giá hai bên), `payments-payouts-design` (M1–M8, hai mốc, thuế khấu trừ thợ cá nhân), `provider-types-portfolio-jobs-design` (hợp đồng kiểu freelancer, Đăng việc), `identity-verification-design` (V1–V7), `terms-and-help-notes`, CLAUDE.md "Money and contact rules".

---

## 0. Tóm tắt điều hành

1. Pháp luật VN: "cộng tác viên" **không phải loại hợp đồng riêng**. Nếu thực chất là làm việc có trả công và chịu quản lý, điều hành, giám sát thì bị coi là hợp đồng lao động bất kể tên gọi (Điều 13 BLLĐ 2019) và kéo theo BHXH. Nếu là hợp đồng dịch vụ dân sự (Điều 513 BLDS 2015), thì không có BHXH, bên trả thù lao có thể phải khấu trừ TNCN 10%.
2. Số liệu thuế đã đổi so với đề bài: từ **01/07/2026**, ngưỡng khấu trừ 10% với thu nhập vãng lai là **5.000.000đ/lần** (NĐ 253/2026/NĐ-CP, Điều 50 khoản 2), không còn 2.000.000đ; TT 111/2013 được TT 87/2026/TT-BTC thay thế (một nguồn, **[CHƯA XÁC NHẬN]** số hiệu mẫu cam kết mới).
3. Nền tảng chỉ là bên khấu trừ-nộp thay (NĐ 117/2025, nay thêm Chương III NĐ 252/2026 và TT 90/2026) khi nền tảng có chức năng đặt hàng **và** thanh toán, và khoản đó là **doanh thu bán hàng/dịch vụ của người bán** trên sàn. Khoản studio trả thợ cộng tác là **chi phí của studio**, không phải doanh thu bán trên sàn. Nền tảng tự trả hộ khoản này sẽ tạo vai trò mới (bên chi trả thu nhập) và nguy cơ đánh thuế hai lần. Đây là lý do chính để **không chia tiền trong app ở phase 1**.
4. Các sàn tương tự (Upwork Agency, Fiverr Studios) đều theo mô hình: khách hợp đồng/thanh toán cho **agency/studio**, agency tự trả thành viên **ngoài nền tảng**. Khớp với T11 của ta.
5. **Khuyến nghị phase 1: phương án B có cấu trúc** ("B+"): cộng tác viên = thợ đã xác minh, có **quan hệ cộng tác hai bên đồng ý** với studio, được **giao từng booking** bằng luồng S26 (có chấp nhận từng việc); tiền vẫn chỉ trả cho studio theo hai mốc, studio trả thợ ngoài app, app ghi mức thù lao khai báo + xác nhận "đã trả/đã nhận". Hoãn: chia tiền trong app, khấu trừ thuế thay cho cộng tác viên, mọi dạng tuyển nhân viên (hợp đồng lao động).

---

## 1. Pháp luật Việt Nam

### 1.1 Cộng tác viên, hợp đồng lao động, hợp đồng dịch vụ

| Vấn đề | Nội dung | Nguồn |
|---|---|---|
| Định nghĩa HĐLĐ | Điều 13 BLLĐ 2019: thỏa thuận về việc làm có trả công, tiền lương, điều kiện lao động; hai bên đặt tên khác nhưng có nội dung việc làm có trả công, tiền lương và **sự quản lý, điều hành, giám sát** của một bên thì **là HĐLĐ**. Ba dấu hiệu: thỏa thuận làm việc, có trả lương, có quản lý-điều hành-giám sát. | [thuvienphapluat (cộng tác viên có phải ký HĐLĐ)](https://thuvienphapluat.vn/lao-dong-tien-luong/cong-tac-vien-co-phai-ky-hop-dong-lao-dong-hay-khong-2901.html) (trang không tải được trực tiếp, nội dung lấy từ kết quả tìm kiếm); [baolamdong "3 yếu tố nhận diện HĐLĐ"](https://baolamdong.vn/3-yeu-to-nhan-dien-hop-dong-lao-dong-394835.html); tra cứu 2026-10-07 |
| Hợp đồng cộng tác viên | Thường là **hợp đồng dịch vụ** (Điều 513 BLDS 2015): bên cung ứng làm công việc, bên sử dụng trả thù lao. Không có nghĩa vụ BHXH/BHYT/BHTN trừ khi thỏa thuận khác. | [luatlongphan](https://luatlongphan.vn/?p=72370) và kết quả trên |
| Bị xếp lại thành quan hệ lao động khi | Làm chủ yếu cho một bên, báo cáo cho quản lý, giờ giấc cố định, dùng hệ thống của bên thuê, nhận tiền cố định hàng tháng, xin phép nghỉ. Gọi là "consultant/freelancer/service provider" không bảo vệ được. | [Duane Morris Vietnam, 2026-08-12](https://blogs.duanemorris.com/vietnam/2026/08/12/vietnam-employment-compliance-2026-the-new-cost-of-doing-business-what-foreign-investors-need-to-fix-now/) |
| BHXH | Luật BHXH 2024 (hiệu lực 01/07/2025): bắt buộc với người làm việc theo HĐLĐ từ **1 tháng** trở lên, mở rộng cả lao động bán thời gian đủ điều kiện; Luật Việc làm 2025 (từ 01/01/2026) mở rộng BHTN cho lao động ngắn hạn. Hậu quả bị xếp lại: truy đóng khoảng 23,5% lương bộ cho cả thời gian + phạt chậm đóng 0,03%/ngày. | cùng bài Duane Morris |
| Nền tảng gig | Vị thế lao động của lao động nền tảng chưa thống nhất giữa các bộ; tranh luận công khai về Grab (đối tác hay lao động). | [Fairwork Vietnam 2023](https://fair.work/wp-content/uploads/sites/17/2023/10/Fairwork-Vietnam-Ratings-2023-English.pdf); [diendandoanhnghiep](https://diendandoanhnghiep.vn/che-tai-dam-bao-quyen-loi-cho-tai-xe-xe-cong-nghe-tai-sao-khong-193726.html) |

**Hệ quả thiết kế** (đây là dấu hiệu rủi ro, không phải tuyên bố pháp lý): cộng tác viên theo từng buổi chụp, tự có thiết bị, tự nhận hay từ chối từng việc, phục vụ nhiều studio, không có giờ làm cố định, không bị studio chỉ huy cách chụp, thì gần hợp đồng dịch vụ. Studio muốn "thợ trực ca, đồng phục, báo cáo hằng ngày" thì là nhân viên, ngoài phạm vi app.

Tín hiệu app nên **tránh tạo ra**: độc quyền (cấm làm cho studio khác), lịch cố định, mức tiền cố định theo tháng, chấm công, đánh giá nội bộ kiểu nhân sự. Tín hiệu cảnh báo mềm: một cộng tác viên nhận phần lớn việc từ một studio liên tục (ngưỡng đề xuất, **[CHƯA XÁC NHẬN]**: > 8 việc/tháng từ một studio trong 3 tháng liền) thì hiện nhắc cả hai bên "dấu hiệu có thể bị coi là quan hệ lao động".

Tuyển dụng nhân viên: đăng tin tuyển việc làm có thể chạm quy định dịch vụ việc làm (Luật Việc làm, NĐ 23/2021) **[CHƯA XÁC NHẬN, chưa tra được]**. Phase 1 chỉ cho hai loại tin: "cộng tác viên theo việc" và "thành viên studio (S26)", không có loại "nhân viên chính thức", và bài đăng miễn phí, không thu phí môi giới.

### 1.2 Thuế TNCN đối với khoản trả cho cộng tác viên

| Mục | Nội dung (cập nhật 2026) | Nguồn |
|---|---|---|
| Khấu trừ 10% | Bên trả thu nhập cho cá nhân **cư trú** không ký HĐLĐ hoặc ký HĐLĐ dưới 3 tháng, mức chi **từ 5 triệu/lần** trở lên phải khấu trừ 10%; **dưới 5 triệu/lần** chỉ khấu trừ khi cá nhân yêu cầu. Từ 01/07/2026, NĐ 253/2026/NĐ-CP (Điều 50, khoản 2). Trước đó: từ 2 triệu/lần (Điều 25 TT 111/2013). | [luatvietnam, 2026](https://luatvietnam.vn/tin-van-ban-moi/chinh-thuc-nang-nguong-khau-tru-thue-thu-nhap-vang-lai-len-5-trieu-dong-lan-tu-01-7-2026-186-110066-article.html); [thuvienphapluat tổng hợp](https://thuvienphapluat.vn/phap-luat/de-xuat-nang-muc-khau-tru-10-thu-nhap-vang-lai-tu-2-trieu-len-5-trieu-dong-tu-ky-tinh-thue-2026-ra--462941-265505.html). Hai nguồn tóm tắt không thống nhất chữ "cư trú/không cư trú" **[CHƯA XÁC NHẬN]**, cần đọc nguyên văn NĐ 253/2026. |
| Văn bản nền | TT 87/2026/TT-BTC (từ 01/07/2026) thay TT 111/2013 theo một nguồn tìm kiếm. | [lawnet](https://lawnet.vn/thong-tin-phap-luat/en/tu-van-luat/vietnam-commitment-form-02-ck-tncn-for-personal-income-tax-exemption-142216.html) (kết quả tìm kiếm); **[CHƯA XÁC NHẬN]** |
| Cam kết không khấu trừ | Cá nhân chỉ có một nguồn thu, tổng thu nhập ước tính dưới mức chịu thuế, có mã số thuế: làm cam kết gửi bên trả. Mẫu: **08/CK-TNCN** (TT 80/2021, thay 02/CK-TNCN của TT 92/2015). Không phải 02. Số hiệu mẫu theo TT 87/2026 **[CHƯA XÁC NHẬN]**. | [luatvietnam "mẫu cam kết 08"](https://luatvietnam.vn/thue-phi-le-phi/mau-cam-ket-08-565-34780-article.html) |
| Không cư trú | 20% trên tổng thù lao dịch vụ (TT 111/2013 Điều 18, 25); nhà cung cấp nước ngoài có quy định riêng. | kết quả tìm kiếm thuvienphapluat trên |
| Mức tiền thực tế | Thù lao một buổi chụp phụ/cộng tác thường vài trăm nghìn tới vài triệu đồng **[CHƯA XÁC NHẬN, ước tính nội bộ]**: phần lớn khoản dưới 5 triệu/lần, nên khấu trừ bắt buộc ít khi kích hoạt; cá nhân tự kê khai theo thu nhập kinh doanh. | |
| Cá nhân kinh doanh | Từ 2026 bỏ thuế khoán, doanh thu dưới 500 triệu/năm được miễn theo các bài tổng hợp; Luật TNCN sửa đổi (hiệu lực chủ yếu 01/07/2026). | [xcyber](https://xcyber.vn/?p=10152), [luatvietan](https://luatvietan.vn/cach-tinh-thue-ho-kinh-doanh-2026-khi-bo-thue-khoan-sang-ke-khai-va-tu-nop-thue.html) **[CHƯA XÁC NHẬN ngưỡng 500 triệu và ngày áp dụng]** |

Hệ quả: Ở phương án trả ngoài app, **studio là bên chi trả**, chịu nghĩa vụ khấu trừ nếu đủ điều kiện; app nên cho studio mẫu "phiếu xác nhận thù lao" và cho cộng tác viên chức năng xuất "tổng thu nhập nhận từ studio trong tháng/năm" (không phải chứng từ khấu trừ).

### 1.3 Nghĩa vụ của nền tảng khi trả hộ

| Mục | Nội dung | Nguồn |
|---|---|---|
| Phạm vi khấu trừ của sàn | NĐ 117/2025/NĐ-CP (ban hành 09/06/2025, hiệu lực 01/07/2025): sàn **có chức năng thanh toán** phải khấu trừ, kê khai, nộp thay GTGT và TNCN cho **hộ, cá nhân kinh doanh** trên **từng giao dịch** khi xác nhận thành công. Sàn không có chức năng thanh toán thì người bán tự kê khai. Tỉ lệ cho dịch vụ (cá nhân cư trú): GTGT 5% + TNCN 2% trên doanh thu. | [MISA AMIS tóm tắt NĐ 117/2025](https://amis.misa.vn/228691/moi-nghi-dinh-117-2025/); [vneconomy](https://vneconomy.vn/san-da-nop-thue-thay-ho-kinh-doanh-online-co-can-ke-khai-va-phat-hanh-hoa-don.htm) |
| Văn bản mới 2026 | Luật Quản lý thuế 108/2025/QH15 (hiệu lực 01/07/2026); NĐ 252/2026/NĐ-CP (Chương III: kê khai, nộp thuế trên nền tảng TMĐT và nền tảng số); TT 90/2026/TT-BTC (mã số thuế riêng cho chủ quản nền tảng); NĐ 253/2026 (TNCN); NĐ 254/2026 (hóa đơn điện tử); TT 87, 89, 91/2026. | [luatvietnam tổng hợp](https://luatvietnam.vn/thue-phi-le-phi/tong-hop-van-ban-huong-dan-thue-hoa-don-tren-san-thuong-mai-dien-tu-565-111128-article.html); [einvoice NĐ 252](https://einvoice.vn/tin-tuc/diem-noi-bat-nghi-dinh-252-voi-nguoi-kinh-doanh) |
| Quan hệ 117/2025 với 252/2026 | Không tra được văn bản nói rõ thay thế hay bổ sung, và tỉ lệ cho từng ngành (nhiếp ảnh có thuộc nhóm "dịch vụ 5%+2%" hay nhóm khác) **[CHƯA XÁC NHẬN]**. Spec thanh toán M8 vẫn dẫn 117/2025: cần cập nhật khi kế toán xác nhận. | |
| Trả hộ cộng tác viên | Tìm không thấy quy định riêng cho nền tảng **chi hộ thù lao giữa hai thành viên**. Suy luận (không phải kết luận pháp lý): 117/2025 đánh trên doanh thu người bán; khoản studio trả thợ là chi phí của studio. Nếu nền tảng chi hộ, nền tảng dễ bị coi là bên chi trả thu nhập (khấu trừ 10% theo NĐ 253 khi ≥ 5 triệu) và bản thân studio (nếu là cá nhân) vẫn bị khấu trừ 117/2025 trên **toàn bộ** doanh thu, gồm phần đã chuyển cho thợ, nên hai lớp thuế lên cùng một dòng tiền. **[CHƯA XÁC NHẬN, hỏi kế toán]** | |
| Cấu trúc thay thế | Nếu muốn chia tiền trong app: coi cộng tác viên là **người bán thứ hai** của cùng booking (khách trả hai khoản, hợp đồng với hai bên), mỗi người chịu 117/2025 trên phần của mình. Khi đó khách hợp đồng với cả hai, đổi tính chất "khách hợp đồng với studio" của S26. | |

Ghi chú cho spec: luật TMĐT 122/2025 và NĐ 248/2026 (xác thực danh tính người bán, từ 01/01/2027) đã nằm trong spec xác minh; cộng tác viên phải có xác minh nên khớp.

---

## 2. Cách các nền tảng khác xử lý studio ↔ freelancer

| Nền tảng | Khách hợp đồng với ai | Tiền | Ai trả thợ/thành viên, thuế | Đánh giá | Ghi chú | Nguồn |
|---|---|---|---|---|---|---|
| Upwork Agency | Khách thuê một **thành viên cụ thể**, nhưng mọi hợp đồng thanh toán **vào tài khoản agency** | Escrow/milestone như thường, phí 0–15% (từ 05/2025), agency trả thành viên **ngoài Upwork** | Agency (không qua nền tảng) | Không rõ cách quy cho thành viên hay agency trong trích dẫn đã đọc | Thành viên hiển thị khác freelancer độc lập; agency được thông báo và có thể tham gia đàm phán | [Upwork Help: About Agencies](https://support.upwork.com/hc/en-us/articles/211062598-About-Agencies); [gigradar](https://gigradar.io/blog/upwork-agency-account) |
| Fiverr Studios | Khách có **một đầu mối, một brief, một giá cố định** cho cả nhóm | Nền tảng nhận, chia cho nhóm freelancer theo thỏa thuận nhóm | **[CHƯA XÁC NHẬN]** chi tiết chia tiền và thuế (trang gốc 403) | | Mô hình "nhóm freelancer ghép kỹ năng" | [Fiverr press qua qumracapital](https://qumracapital.com/news/the-launch-of-fiverr-studios-changes-the-way-freelancers-work-together/) |
| Thumbtack | Khách với từng pro | Pro tự xử lý nhân sự | Không có tính năng "helper" chính thức (không tìm thấy) | Theo pro | | kết quả tìm kiếm 2026-10-07 |
| Grab Việt Nam | Khách với Grab/đối tác tài xế | Grab thu, chia 75–80% cho đối tác; khấu trừ thuế theo tỉ lệ cố định (ví dụ TNCN 1,5% được báo cáo) | Nền tảng khấu trừ; tranh cãi "đối tác hay người lao động" | Nền tảng | Bài học: mô hình "đối tác" bị phản biện là che quan hệ lao động khi nền tảng quản lý chặt | [diendandoanhnghiep](https://diendandoanhnghiep.vn/che-tai-dam-bao-quyen-loi-cho-tai-xe-xe-cong-nghe-tai-sao-khong-193726.html); [vietnamfinance](https://vietnamfinance.vn/grab-da-bong-ap-thue-vat-len-tai-xe-d58830.html) |
| Nghề chụp ảnh cưới (second shooter) | Khách ký với studio/thợ chính | Thợ chính trả second shooter theo buổi/giờ, hợp đồng cộng tác, điều khoản bản quyền và bảo mật thoả thuận trước | Thợ chính | Khách đánh giá studio/thợ chính | Hợp đồng mẫu có điều khoản bản quyền, không cạnh tranh trực tiếp | [SLR Lounge second shooter contract](https://www.slrlounge.com/second-shooter-contract-sample/); [neilvn](https://neilvn.com/tangents/tips-for-2nd-shooting-weddings/) |
| vLance, Freelancerviet, TopCV, ITviec | Chưa tra được chi tiết chính sách studio-nhóm; vLance/Freelancerviet là sàn việc theo dự án có ký quỹ; TopCV/ITviec là tin tuyển dụng (nhân viên) không phải gig | | | | **[CHƯA XÁC NHẬN]**: chưa tìm tài liệu chính thống về phí/ký quỹ của vLance; trang Freelancerviet có mô tả quy trình khách-freelancer: [freelancerviet](https://freelancerviet.vn/en/how-it-works/client/freelance.html) | |

Mẫu chung rút ra:
- **Một bên hợp đồng với khách** (agency/studio), thợ phụ là người thực hiện: Upwork Agency, Fiverr Studios, ảnh cưới. Khớp S26.
- **Chia tiền trong nhóm do nhóm tự lo**, nền tảng chỉ trả cho agency (Upwork). Nền tảng nào chia hộ (Grab) đều đối mặt tranh cãi phân loại lao động và thuế.
- Mời theo từng việc (per-job invitation) và mức thù lao khai báo là thực hành chuẩn ở ngành chụp ảnh.

---

## 3. Các phương án sản phẩm

Ký hiệu: Studio = bên ký với khách; CTV = cộng tác viên; "S26" = quy tắc thành viên hiện có.

### 3.1 Mô tả ngắn

- **A. CTV theo từng booking + chia tiền trong app**: studio mời CTV vào danh sách cộng tác, giao từng booking kèm thù lao cố định hoặc %, CTV chấp nhận; tiền khách trả vẫn về studio, nhưng khi nhả mốc, tổ chức trung gian **chi trực tiếp phần CTV** cho CTV.
- **B. CTV theo từng booking, trả ngoài app** ("B+" ở khuyến nghị): cùng cơ chế quan hệ cộng tác và giao việc như A, nhưng app **chỉ ghi** mức thù lao khai báo và trạng thái đã trả/đã nhận, không chi tiền.
- **C. Thành viên cố định (S26 hiện có)**: tối đa một studio, chặn rời khi còn việc, đếm thợ 3/30.

### 3.2 So sánh

| Tiêu chí | A. CTV + chia tiền trong app | B. CTV, trả ngoài app (có ghi nhận) | C. Thành viên (S26) |
|---|---|---|---|
| Dòng tiền với escrow 100% + hai mốc | Phức tạp: mỗi mốc phải tách thành 2 lệnh chi (studio, CTV) và xử lý hoàn tiền/khiếu nại khi CTV đã nhận; cần đối tác chi hộ nhiều người nhận | Không đổi: tiền → studio theo hai mốc (T11) | Không đổi |
| Thuế | Nền tảng/studio phải khấu trừ 10% (≥ 5 triệu/lần, hoặc theo yêu cầu) cho CTV; nguy cơ hai lớp thuế với studio cá nhân (117/2025); thêm báo cáo | Studio tự lo; nền tảng chỉ cung cấp bản ghi thù lao | Như B (studio tự chia) |
| Mở khóa liên hệ | Như B | CTV chỉ thấy liên hệ khách khi: được giao + CTV chấp nhận + khách đã thanh toán (luật S26 §5.7); đóng khi đổi thợ hoặc sau khi booking xong + cửa sổ khiếu nại | Như B |
| Gắn đánh giá | Cà chua/gạch cho CTV (thợ cuối được giao) và cho studio, hai bản ghi như S26 §6 | Như A | Như A |
| Chống spam / chống "đi đường vòng" | Tiền đi qua app nên có dữ liệu thu nhập; vẫn không chặn được CTV chào khách trực tiếp | Dựa vào luật liên hệ, lọc tin nhắn, điều khoản; CTV có hồ sơ công khai vẫn đặt trực tiếp được | Thành viên cố định, ràng buộc nhẹ (thời gian nghỉ 7 ngày) |
| Rủi ro studio không trả CTV | Thấp (chi từ escrow) | **Cao hơn**: cần xác nhận hai bên, cờ báo, khiếu nại | Giống B (T11) |
| Rủi ro pháp lý | Cao nhất: bên chi trả thu nhập, thuế hai lớp, nền tảng bị cho là điều phối lao động | Thấp-vừa: app ghi nhận, không chi; vẫn có rủi ro phân loại nếu studio quản lý chặt | Vừa: thành viên cố định dễ bị xem như lao động hơn |
| Công sức làm | Lớn (đối tác chi hộ, báo cáo thuế, sổ cái, xử lý hoàn) | Vừa (mở rộng S26 + một bảng quan hệ) | Đã có |
| Phù hợp mục tiêu "tuyển thợ linh hoạt" | Cao nhưng sớm | **Cao**, đủ cho phase 1 | Thấp với việc vài buổi/tháng |

### 3.3 Thiết kế đề xuất cho B+ (phase 1)

**Bài đăng tuyển (S27)**
- Chỉ studio đã xác minh danh tính (`acceptingOrders`) đăng; miễn phí; giới hạn 3 tin mở/studio, thời hạn 30 ngày, gia hạn 1 lần; loại tin: `collaborator` (theo việc) hoặc `member` (vào studio, S26). Không có loại nhân viên.
- Nội dung: chuyên mục chụp, khu vực, tần suất dự kiến, mức thù lao tham khảo (theo buổi hoặc %), yêu cầu thiết bị/kinh nghiệm. Cấm số điện thoại/Zalo/link (dùng bộ lọc hiện có).
- **Hiển thị**: Firestore/SQL rules `read` chỉ khi có `photographers/{uid}` hợp lệ (mọi `providerType`, kể cả chưa xác minh) hoặc studio; khách và người chưa đăng nhập không thấy; không lên feed, tìm kiếm khách, sitemap, preview link/OG; thông báo `studio_post_new` chỉ cho thợ khớp khu vực/chuyên mục. Một tài khoản vừa là khách vừa là thợ: chỉ thấy khi đang ở vai trò thợ, kiểm theo vai trò của tài khoản, không theo màn hình.
- Ứng tuyển: chỉ thợ đã xác minh (V2); ≤ 10 ứng tuyển mở mỗi thợ, ≤ 3 mỗi ngày; một ứng tuyển cho mỗi tin; studio duyệt trong 7 ngày (hết hạn tự động, như T2).

**Quan hệ cộng tác** (`studio_collaborations/{studioId}_{uid}`; tách khỏi `studio_members`)
- `invited | requested | active | declined | cancelled | expired | ended`; hai bên đồng ý, TTL 7 ngày (như T2); hai bên có thể kết thúc bất kỳ lúc nào, trừ khi còn booking được giao chưa xong (như T4).
- **Không độc quyền**: CTV có thể cộng tác nhiều studio và vẫn nhận booking cá nhân; thành viên studio A có thể là CTV studio B (hoặc cấm nếu chủ studio A yêu cầu, quyết định cho owner, §6).
- Giới hạn đề xuất (hằng số cấu hình): CTV ≤ **5** cộng tác đang hoạt động; studio chưa xác minh doanh nghiệp ≤ **5** CTV, đã xác minh ≤ **50**, tách khỏi hạn 3/30 thành viên; lời mời chờ ≤ 5; thao tác mỗi ngày: studio ≤ 10 (mời, huỷ, duyệt, kết thúc), thợ ≤ 5; sau khi kết thúc, 3 ngày chưa được mời lại cùng studio (chống lặp lại spam), không có "thời gian nghỉ" 7 ngày như thành viên vì không độc quyền.
- Điều khoản tối thiểu hiển thị khi đồng ý (mẫu app sinh, **[CHƯA XÁC NHẬN]** cần luật sư): hợp đồng dịch vụ dân sự theo việc, CTV tự quyết cách làm, không có giờ làm cố định, không độc quyền, không BHXH, thù lao do hai bên thỏa thuận từng việc, bản quyền ảnh và bàn giao theo hợp đồng của studio với khách, **không chào khách của studio trực tiếp** trong một khoảng sau khi làm việc (đề xuất 6 tháng; hiệu lực pháp lý **[CHƯA XÁC NHẬN]**, BLLĐ Điều 21 chỉ nói về bảo vệ bí mật cho người lao động, hợp đồng dân sự tuân theo tự do thỏa thuận).

**Giao việc** (mở rộng S26.04 `assignBooking`)
- Danh sách chọn thợ gồm thành viên và CTV đang `active`. Với CTV: studio đề xuất `agreedFee` (VND, số nguyên) hoặc `percent`; CTV có **6 giờ chấp nhận/từ chối** từng việc; từ chối không tính vi phạm; hạn giao thợ trước 24 giờ (T6) vẫn áp dụng cho studio, và nếu CTV từ chối sát hạn, studio giao người khác.
- Ghi vào `assignments[]`: `assigneeKind: member | collaborator`, `agreedFee`, `acceptedAt`. Khách thấy đúng khối "Thợ chụp cho bạn" như S26.03, nhãn "Cộng tác với {Studio}"; quyền xin đổi thợ như S26.05. Booking vẫn do studio chịu trách nhiệm với khách (T8 hoàn 100% khi studio lỗi).
- **Trả ngoài app**: sau mốc 1 được nhả cho studio, hệ thống nhắc studio "Trả {tên} {số tiền}" trong 7 ngày; studio bấm "Đã trả" (chọn tháng/ngày, phương thức); CTV bấm "Đã nhận" hoặc "Chưa nhận". Quá 7 ngày chưa trả hoặc CTV báo "Chưa nhận" → cờ `unpaidCollaboratorCount + 1` cho studio, staff xem; lặp lại 3 lần/90 ngày thì tạm khoá quyền đăng tin tuyển và mời CTV. Nền tảng **không bảo lãnh** khoản thù lao (ghi rõ trong điều khoản); tranh chấp thù lao giữa studio và CTV giải quyết ngoài app, nhân viên chỉ ghi nhận để áp biện pháp tài khoản.
- Studio là bên khấu trừ nếu đủ điều kiện (§1.2); app hiển thị nhắc "Khoản từ 5.000.000đ/lần trở lên có thể phải khấu trừ TNCN 10%; hãy hỏi kế toán" một lần và cho xuất bảng kê thù lao theo tháng.

**Liên hệ** (CLAUDE.md "Money and contact rules")
- CTV chỉ thấy tên + (sau thanh toán) kênh liên hệ của khách khi đồng thời: `assigneeId = CTV`, CTV đã chấp nhận, khách đã thanh toán. Địa chỉ đầy đủ hiện sau thanh toán. Số điện thoại không vào hồ sơ công khai (giữ nguyên).
- Liên hệ đóng khi: bị đổi thợ; booking `completed`/`cancelled` + 7 ngày; hoặc CTV bị kết thúc cộng tác khi booking xong. CTV không thấy booking hay khách khác của studio (rules: `assigneeId` chỉ đọc booking được giao).
- Chat 1-1 CTV–khách: chỉ trong hội thoại booking, qua bộ lọc số điện thoại/link hiện có; chat giữa CTV và studio là hội thoại riêng "cộng tác".

**Đánh giá**
- Như S26 §6: khách đánh giá **thợ cuối** và **studio**, hai bản ghi; đánh giá thợ (CTV) cộng vào % cà chua của chính CTV, tag "Qua {Studio} · cộng tác"; tab Đánh giá của studio có tag "Chụp bởi {CTV}".
- Studio → CTV: phase 1 chỉ có "Đã trả/Đã nhận" và cờ vi phạm; **hoãn** đánh giá hai chiều giữa studio và CTV (dễ thành công cụ trả đũa; nếu muốn, làm riêng, chỉ riêng tư cho staff).

**Chống đi đường vòng (anti-poaching)**
1. Lớp kỹ thuật: lọc liên hệ trong chat, liên hệ chỉ mở theo điều kiện trên, CTV không thấy danh sách khách của studio, không export khách.
2. Lớp điều khoản: cam kết không chào khách của studio trực tiếp trong 6 tháng; vi phạm bị báo cáo → staff có thể tắt khả năng nhận giao việc/gỡ nhãn CTV (biện pháp tài khoản), không phạt tiền trong app.
3. Thực tế: CTV vẫn có hồ sơ công khai và khách tìm thấy được; không nên chặn khách đặt thợ trực tiếp (xâm phạm quyền chọn của khách). Studio nhận rủi ro đó khi dùng CTV; app cho studio ẩn bài "Buổi chụp thật" gắn tag cả hai nếu muốn (phase sau).
4. Số liệu tín hiệu: nếu một CTV có ≥ 2 booking liên tiếp với cùng một khách **ngoài** studio ngay sau khi được giao cho khách đó, gắn cờ cho staff (chỉ ghi, chưa tự xử lý).

---

## 4. Rủi ro tổng hợp và cách giảm

| Rủi ro | Mức | Giảm thiểu |
|---|---|---|
| CTV bị xếp thành lao động (BHXH, truy thu) | Vừa, rơi vào studio | Không độc quyền, không giờ cố định, từng việc có chấp nhận, cảnh báo ngưỡng, điều khoản rõ ràng, không có loại tin "nhân viên" |
| Studio quỵt thù lao CTV | Vừa | Xác nhận hai chiều, cờ, khoá quyền đăng tin; phase sau mới chi hộ (A) |
| Nền tảng bị coi là bên điều phối lao động hoặc dịch vụ việc làm | Chưa rõ | Tin miễn phí, không môi giới có phí, không loại nhân viên **[CHƯA XÁC NHẬN, luật sư]** |
| Thuế hai lớp nếu chi hộ | Cao nếu làm A | Hoãn A, hỏi kế toán trước |
| Khách bị lộ liên hệ cho người chưa giao | Thấp | Rules như §3.3 liên hệ |
| Tin tuyển lộ cho khách | Thấp nhưng nhạy | Rules theo vai trò, test rules cho khách, không SEO/preview |
| CTV bị lạm dụng (làm cho nhiều studio, hết lịch) | Thấp | Lịch bận dùng chung (T1), ≤ 5 cộng tác, nhận từng việc |

---

## 5. Khuyến nghị

**Phase 1 (an toàn pháp lý nhất, vừa với thiết kế hiện có): B+**
1. S27: bài đăng tuyển miễn phí chỉ cho thợ và studio; ứng tuyển cần xác minh; hai loại `collaborator` và `member`.
2. Quan hệ cộng tác hai bên đồng ý, không độc quyền, giới hạn 5 studio/CTV, 5/50 CTV/studio, TTL 7 ngày, thao tác/ngày.
3. Giao việc theo từng booking tái dùng S26 (giao ≥ 24 giờ, đổi thợ, xin đổi, đánh giá hai bên), thêm chấp nhận 6 giờ và `agreedFee` khai báo.
4. Tiền không đổi: 100% → studio theo hai mốc; studio trả CTV ngoài app, app ghi "Đã trả/Đã nhận" và cờ vi phạm; studio là bên khấu trừ.
5. Liên hệ khách mở cho CTV chỉ khi được giao + chấp nhận + đã thanh toán; đóng khi đổi thợ hoặc xong.
6. Điều khoản: hợp đồng dịch vụ dân sự, không bảo lãnh thù lao, cam kết không chào khách trực tiếp.

**Hoãn**
- Chia tiền/chi hộ trong app cho CTV (A) và nền tảng khấu trừ 10% cho CTV: chỉ khi luật sư/kế toán xác nhận (a) tư cách bên chi trả của nền tảng, (b) cách tránh hai lớp thuế với 117/2025, (c) đối tác chi hộ nhiều người nhận (thêm điều kiện số 7 vào spec thanh toán §10).
- Đánh giá hai chiều studio ↔ CTV, xếp hạng công khai CTV theo studio.
- Loại tin "nhân viên chính thức", mọi quản lý nhân sự (chấm công, lương), BHXH.
- Vai trò "quản lý" trong studio; giao nhiều thợ một booking.
- Chia theo % trong app (cần thuế và hoàn tiền cho mỗi phần).

---

## 6. Câu hỏi mở cho chủ sản phẩm / pháp lý

1. Thành viên studio A được làm CTV cho studio B không (mặc định: được, không độc quyền)?
2. Studio có chọn "chỉ CTV đã xác minh" hay chấp nhận cả thợ chưa nhận đơn? (Phase 1 đề xuất đã xác minh, vì spec V2 yêu cầu xác minh để được giao việc.)
3. Thời hạn cam kết không chào khách (đề xuất 6 tháng) có nên là điều khoản công khai không, và có đủ hiệu lực với cá nhân không (luật sư).
4. Có cho cộng tác "trả theo %" trong phase 1 không, khi app không chia tiền? (Đề xuất: chỉ khai báo số tiền cố định/buổi, % quy ra số tiền lúc giao việc.)
5. Cập nhật spec thanh toán M8 và §7 theo NĐ 252/2026, TT 90/2026, NĐ 253/2026, TT 87/2026 (kế toán xác nhận tỉ lệ nhiếp ảnh).
6. Tin tuyển có thể thuộc "dịch vụ việc làm" có điều kiện không (luật sư).

---

## 7. Nguồn (tra cứu 2026-10-07)

- BLLĐ 2019 Điều 13, hợp đồng cộng tác viên: https://thuvienphapluat.vn/lao-dong-tien-luong/cong-tac-vien-co-phai-ky-hop-dong-lao-dong-hay-khong-2901.html ; https://baolamdong.vn/3-yeu-to-nhan-dien-hop-dong-lao-dong-394835.html ; https://luatlongphan.vn/?p=72370
- Phân loại, BHXH 2024, phạt chậm đóng: https://blogs.duanemorris.com/vietnam/2026/08/12/vietnam-employment-compliance-2026-the-new-cost-of-doing-business-what-foreign-investors-need-to-fix-now/
- Khấu trừ 10%, ngưỡng 5 triệu, NĐ 253/2026: https://luatvietnam.vn/tin-van-ban-moi/chinh-thuc-nang-nguong-khau-tru-thue-thu-nhap-vang-lai-len-5-trieu-dong-lan-tu-01-7-2026-186-110066-article.html ; https://thuvienphapluat.vn/phap-luat/de-xuat-nang-muc-khau-tru-10-thu-nhap-vang-lai-tu-2-trieu-len-5-trieu-dong-tu-ky-tinh-thue-2026-ra--462941-265505.html
- Mẫu cam kết 08/CK-TNCN, TT 87/2026: https://luatvietnam.vn/thue-phi-le-phi/mau-cam-ket-08-565-34780-article.html ; https://lawnet.vn/thong-tin-phap-luat/en/tu-van-luat/vietnam-commitment-form-02-ck-tncn-for-personal-income-tax-exemption-142216.html
- NĐ 117/2025 và tỉ lệ: https://amis.misa.vn/228691/moi-nghi-dinh-117-2025/ ; https://vneconomy.vn/san-da-nop-thue-thay-ho-kinh-doanh-online-co-can-ke-khai-va-phat-hanh-hoa-don.htm
- Văn bản 2026 (Luật QLT 108/2025, NĐ 252, 253, 254, TT 87–91/2026): https://luatvietnam.vn/thue-phi-le-phi/tong-hop-van-ban-huong-dan-thue-hoa-don-tren-san-thuong-mai-dien-tu-565-111128-article.html ; https://einvoice.vn/tin-tuc/diem-noi-bat-nghi-dinh-252-voi-nguoi-kinh-doanh
- Luật TNCN sửa đổi 2025: https://pbgdpl.cantho.gov.vn/tu-ngay-0172026-nhieu-diem-moi-cua-luat-thue-thu-nhap-ca-nhan-can-luu-y ; https://xcyber.vn/?p=10152
- Upwork Agency: https://support.upwork.com/hc/en-us/articles/211062598-About-Agencies
- Fiverr Studios: https://qumracapital.com/news/the-launch-of-fiverr-studios-changes-the-way-freelancers-work-together/
- Second shooter: https://www.slrlounge.com/second-shooter-contract-sample/
- Grab/đối tác: https://diendandoanhnghiep.vn/che-tai-dam-bao-quyen-loi-cho-tai-xe-xe-cong-nghe-tai-sao-khong-193726.html ; https://vietnamfinance.vn/grab-da-bong-ap-thue-vat-len-tai-xe-d58830.html

Giới hạn tra cứu: chỉ đọc được tóm tắt của một số trang; không đọc nguyên văn các nghị định/thông tư; một số trang (thuvienphapluat, Fiverr) trả 403 nên nội dung lấy từ đoạn kết quả tìm kiếm.
