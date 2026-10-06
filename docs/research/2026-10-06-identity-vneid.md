# Nghiên cứu: xác minh danh tính bằng VNeID cho thợ ảnh và studio

Ngày 2026-10-06. Cách đánh dấu: **[XN]** = đã xác nhận từ nguồn chính thức hoặc báo lớn; **[TC]** = nguồn thứ cấp (blog luật, nhà cung cấp tự công bố); **[CHƯA XN]** = suy đoán hoặc chưa tìm được nguồn, cần hỏi nhà cung cấp hoặc luật sư.

Hiện trạng trong repo: S21.01 (OTP SĐT) và S21.02 (xin tích xanh: hồ sơ ≥ 80%, ≥ 3 buổi `completed`, gửi giấy tờ, staff duyệt ở S23.04, giấy tờ xoá sau 30 ngày) mới có trong spec chính §3i.4, chưa có mock, chưa có đặc tả màn. Code chỉ có `VerifiedMark`/`ProviderMark` (hiện dấu khi `verified = true`) và mã màn `S21.01`, `S21.02`, `S23.04` trong `screen_codes.dart`. Studio dùng S21.02 "nhánh studio" (giấy phép kinh doanh); spec studio-members giới hạn 3 thợ (chưa xác minh) / 30 (đã xác minh). `PayoutAccount` đã có `holderName`, số tài khoản mã hoá.

---

## (A) Khuyến nghị cho app

### Phát hiện làm đổi thiết kế

1. **Luật Thương mại điện tử 122/2025/QH15** (hiệu lực 01/7/2026) Điều 17: chủ nền tảng TMĐT trung gian phải **xác thực điện tử danh tính người bán trước khi cho hoạt động**, "theo quy định về định danh và xác thực điện tử" (tức Nghị định 69/2024, hệ thống VNeID) **[XN]**. **Nghị định 248/2026/NĐ-CP** Điều 18: thông tin xác thực của cá nhân là họ tên, ngày sinh, số định danh cá nhân; của tổ chức là tên, trụ sở, số định danh tổ chức, cùng họ tên, ngày sinh và số định danh của người đại diện theo pháp luật. Nghĩa vụ này **áp dụng từ 01/01/2027**; nền tảng đang hoạt động có thể có hạn tới 30/6/2027 **[TC]**. App là sàn trung gian bán dịch vụ chụp ảnh và có thu tiền, nên **rất có thể thuộc phạm vi luật này [CHƯA XN, cần luật sư]**.
2. Bộ đôi Luật Bảo vệ dữ liệu cá nhân 91/2025/QH15 và Nghị định 356/2025 thay Nghị định 13/2023 từ 01/01/2026 **[XN]**. Dữ liệu sinh trắc (ảnh khuôn mặt) là dữ liệu **nhạy cảm**. Doanh nghiệp nhỏ hay khởi nghiệp **mất quyền miễn** lập hồ sơ đánh giá tác động nếu tự xử lý dữ liệu nhạy cảm **[XN]**.
3. Từ 01/7/2025, **số định danh cá nhân được dùng thay mã số thuế** của cá nhân và hộ kinh doanh (Thông tư 86/2024) **[XN]**. Theo Nghị định 117/2025, sàn TMĐT có chức năng thanh toán phải khấu trừ và nộp thay thuế cho cá nhân kinh doanh **[XN]**. Như vậy, sớm muộn gì app cũng cần số định danh của thợ ảnh để nộp thuế thay.

→ Vì vậy nên đổi thiết kế: xác minh danh tính trở thành **điều kiện nhận đơn** (cổng bắt buộc, kín). Hiện nay xác minh chỉ dẫn tới dấu tích xanh mà thợ tự xin khi đã đủ thành tích.

### Làm ngay và làm sau

| Giai đoạn | Làm gì |
|---|---|
| **Ngay (v1)** | Viết port `IdentityVerifier` ở domain, chưa phụ thuộc nhà cung cấp nào, cùng trạng thái `identity: none / pending / verified / rejected / needs_more`. Adapter đầu tiên là **eKYC đọc chip CCCD qua NFC, so khuôn mặt và kiểm tra liveness**, qua một nhà cung cấp có đối chiếu RAR‑C06 (FPT.AI, VNPT, TrustingSocial…). Thiết bị không có NFC thì dùng adapter dự phòng `ManualReview`: ảnh CCCD và selfie, staff duyệt ở S23.04. Bước OTP SĐT (S21.01) đi trước. Tài khoản nhận tiền chỉ hỏi khi có khoản tiền đầu tiên. |
| **Trước 01/01/2027** | Thêm adapter **VNeID**: ký hợp đồng trực tiếp với Trung tâm RAR, hoặc qua đối tác tích hợp đã kết nối RAR. Đưa VNeID thành cách mặc định và giữ NFC làm dự phòng, nếu luật sư xác nhận NFC kèm đối chiếu C06 vẫn đạt yêu cầu. |
| **Sau** | Tra tên chủ tài khoản ngân hàng tự động (NAPAS); tra mã số thuế studio tự động; chữ ký số từ xa qua VNeID để ký hợp đồng studio (đã có tiền lệ ở VNDirect **[XN]**). |

Câu hỏi cho chủ sản phẩm: **tách hai khái niệm**. Gợi ý `identityVerified` là cổng nhận đơn, kín, chỉ server ghi. Dấu tích xanh `verified` vẫn là dấu tin cậy công khai, xét theo thành tích như §3i.4. Nếu mọi thợ nhận đơn đều đã xác minh danh tính thì tích xanh "đã xác minh danh tính" không còn phân biệt được ai với ai.

### Luồng từng bước, chỉ hiện khi người dùng muốn nhận đơn

Điểm vào duy nhất là nút **"Bắt đầu nhận đơn"**. Nút này xuất hiện khi thiết lập xong S08.01 (đã có ≥ 1 gói) và ở thẻ checklist trên S09.01. Dựng hồ sơ, đăng portfolio, xem trước hồ sơ đều không cần xác minh. Hồ sơ chưa xác minh không hiện trong tìm kiếm và không đặt được.

| Bước | Hỏi gì | Khi nào | Ghi chú |
|---|---|---|---|
| 1. SĐT | Số điện thoại, OTP | Ngay khi bấm "Bắt đầu nhận đơn" | Bỏ qua nếu `phoneVerified`. |
| 2. Danh tính | **Không gõ gì.** Bấm "Xác minh bằng VNeID", rồi xác nhận chia sẻ thông tin và nhập PIN trong app VNeID. Nếu chưa có VNeID: "Quét chip CCCD", áp CCCD vào điện thoại rồi quay selfie 3–5 giây. | Ngay sau bước 1 | Kết quả trả về: họ tên, ngày sinh, giới tính, số định danh. Màn kết quả chỉ hiện họ tên **đã che bớt** để người dùng xác nhận. Đủ 18 tuổi trở lên mới được nhận đơn. |
| → Bật nhận đơn | | | Một thông báo "Bạn đã có thể nhận đơn". |
| 3. Nhận tiền | Ngân hàng và số tài khoản. Tên chủ tài khoản do hệ thống tra, người dùng không gõ. | Khi có booking đầu tiên được xác nhận, hoặc trước lần giải ngân đầu tiên | Tên chủ tài khoản phải khớp họ tên đã xác minh (mục 4 bên dưới). Không khớp thì giữ tiền ở trạng thái `on_hold`. |
| 4. Thuế | Không hỏi thêm: dùng số định danh làm mã số thuế (Thông tư 86/2024) | Cùng bước 3 | Chỉ cần đồng ý cho sàn khấu trừ và nộp thay. |
| Studio 5. Doanh nghiệp | Mã số doanh nghiệp hoặc mã số hộ kinh doanh | Chỉ khi chủ studio muốn có con dấu Studio, hơn 3 thợ, hoặc nhận tiền vào tài khoản công ty | Xem mục (D). |

Chống làm phiền: một thẻ checklist "Còn n bước để nhận đơn", lưu tiến độ để làm tiếp. Nhắc tối đa **một** thông báo, sau 3 ngày nếu bỏ dở. Không email, không hỏi lại thông tin đã lấy được từ chip hoặc VNeID.

Kỹ thuật: Cloud Functions chỉ giữ adapter, gồm callable `startIdentityVerification` và webhook kết quả, theo đúng quy tắc tách Firebase. RAR và các bên trung gian thường đòi **mTLS và whitelist IP** **[XN qua tài liệu GTEL/VietQR]**. Functions cần IP ra cố định (Cloud NAT) **[CHƯA XN với RAR]**.

---

## (B) VNeID: tích hợp thực tế, pháp lý, quy trình

- **Pháp lý [XN]**: Luật Căn cước 2023 (hiệu lực 01/7/2024); Nghị định 69/2024/NĐ-CP về định danh và xác thực điện tử (hiệu lực 01/7/2024); Nghị định 70/2024 hướng dẫn Luật Căn cước. Xác thực điện tử là ngành kinh doanh có điều kiện, nhà cung cấp phải thuộc lực lượng Công an (Điều 22–23). **Trung tâm RAR (C06, Bộ Công an) là đơn vị duy nhất được cấp phép** (CAND, 15/8/2024). Theo Điều 27, công dân không mất phí, còn tổ chức khai thác dịch vụ trả phí theo giá của nhà cung cấp.
- **Các dịch vụ của RAR [XN]**: (1) **SSO**, đăng nhập bằng tài khoản VNeID; (2) **chia sẻ thông tin** từ tài khoản định danh, **cần công dân đồng ý**; (3) **xác thực thông tin**: gửi các trường dữ liệu, nhận lại đúng hoặc sai; (4) **xác thực sinh trắc khuôn mặt** đối chiếu Cơ sở dữ liệu căn cước. Dịch vụ chạy 24/7.
- **Ai đã dùng [XN]**: ngân hàng (Sacombank, Agribank, BIDV, VietinBank, OCB, Techcombank), chứng khoán (VNDirect, 8/2025), ví (MoMo, 9Pay 7/2025), viễn thông, chuỗi nhà thuốc Long Châu. Như vậy **doanh nghiệp ngoài ngành tài chính cũng ký được**. Chưa thấy nền tảng nhỏ hay startup nào công bố ký trực tiếp **[CHƯA XN]**.
- **Luồng người dùng [XN, theo hướng dẫn của VNDirect]**: trong app, người dùng bấm xác nhận đồng ý chia sẻ. Hệ thống gửi yêu cầu sang VNeID. Người dùng mở VNeID, vào **Thông báo**, mở yêu cầu, xem các trường sẽ chia sẻ, bấm "Xác nhận chia sẻ" rồi nhập **PIN**. Các trường được đối chiếu gồm họ tên, số CCCD, ngày sinh, giới tính. 9Pay mô tả luồng của họ là **app‑to‑app**, có thêm sinh trắc khuôn mặt, không cần NFC **[XN]**. QR hoặc deeplink chuẩn OAuth: chưa có tài liệu công khai **[CHƯA XN]**.
- **Dữ liệu trả về**: tối thiểu họ tên, số định danh, ngày sinh, giới tính **[XN]**. Ảnh chân dung và địa chỉ: **[CHƯA XN]**; có thể phụ thuộc gói chia sẻ đã ký.
- **Đăng ký, chi phí, thời gian [CHƯA XN]**: RAR không công bố bảng giá. Theo các bài báo, quy trình là đăng ký với RAR, chuẩn bị điều kiện kỹ thuật và an ninh, rồi ký hợp đồng. Bên trung gian (V9, GTEL/VietQR, VNPT) quảng cáo môi trường thử "1–3 ngày làm việc" **[TC]**, nhưng chưa rõ thời gian ký hợp đồng chính thức. Cần pháp nhân Việt Nam, có thể cần chứng nhận an toàn hệ thống thông tin. **Việc phải làm**: gửi văn bản hỏi RAR (rarcenter.vn) và lấy báo giá của 2–3 bên trung gian.

---

## (C) Phương án eKYC thay thế

Cách làm: đọc chip CCCD qua NFC, rồi kiểm tra chữ ký số của Bộ Công an trên chip, hoặc đối chiếu RAR‑C06 để biết chip thật hay giả. Sau đó so ảnh trong chip với selfie có kiểm tra liveness. Cách này không cần VNeID, nhưng người dùng phải có CCCD gắn chip và điện thoại có NFC.

| Nhà cung cấp | NFC + đối chiếu C06 | Face match / liveness | SDK | Giá công khai |
|---|---|---|---|---|
| VNPT eKYC / IDCheck | Có, "RAR‑C06" **[XN]** | Có | Android, iOS, Web; không thấy Flutter | eKYC gói 800.000đ/tháng cho 1.000 request (100 Face ID), 2,4tr/3.000, 4tr/5.000, chưa VAT **[TC]**. IDCheck: gói theo số request, không công bố giá. |
| FPT.AI eKYC | Có, kiểm tra C06 **[TC]** | Có | Android, iOS, Web; không có Flutter chính thức | Liên hệ |
| Viettel AI eKYC | Có OCR; NFC/C06 **[CHƯA XN]** | Có | Android, iOS | Liên hệ |
| TrustingSocial (TrustVision) | Có NFC **[TC]** | Có | **Có Flutter SDK v4** **[XN]** | Liên hệ |
| Kalapa | Có NFC **[TC]** | Có | Android, iOS native | Liên hệ |

Với Flutter: hoặc bọc SDK native bằng platform channel, việc này tốn công nhưng làm được, hoặc chọn TrustingSocial. Giá thường vào khoảng vài trăm tới vài nghìn đồng mỗi lượt **[CHƯA XN, cần báo giá]**.

Rủi ro: Nghị định 248 quy định xác thực "theo quy định về định danh và xác thực điện tử". Chưa rõ eKYC NFC qua bên thứ ba có được tính là đạt hay không **[CHƯA XN]**.

---

## (D) Xác minh studio

- Tra cứu: Cổng thông tin quốc gia về đăng ký doanh nghiệp (dangkykinhdoanh.gov.vn) công khai miễn phí tên, mã số doanh nghiệp, trụ sở, ngành nghề, **họ tên người đại diện theo pháp luật** và tình trạng pháp lý **[XN]**. API công khai `api.vietqr.io/v2/business/{mst}` trả về tên, địa chỉ, tình trạng và có ghi nguồn Cục Thuế (đã gọi thử ngày 06/10/2026). API này **không trả người đại diện** **[XN]**.
- **Luồng đề xuất**:
  1. Chủ studio phải đã xác minh cá nhân (bước 2).
  2. Nhập mã số doanh nghiệp, hệ thống tự điền tên, địa chỉ và tình trạng "đang hoạt động".
  3. So người đại diện theo pháp luật với họ tên đã xác minh của chủ studio. Bước này tự động nếu có API trả người đại diện (dịch vụ trả phí hoặc RAR "định danh tổ chức" **[CHƯA XN]**); nếu chưa có thì staff tra trên cổng.
  4. Nếu không khớp: tải **giấy uỷ quyền** của người đại diện, staff duyệt.
- **Hộ kinh doanh**: từ 01/7/2025, mã số của hộ kinh doanh chính là **số định danh của người đại diện** **[XN]**. Chỉ cần so với số định danh đã xác minh là xong, không cần giấy tờ.
- Giấy tờ hợp lý (chỉ khi tra tự động thất bại): giấy chứng nhận đăng ký doanh nghiệp hoặc hộ kinh doanh, và giấy uỷ quyền. **Không đòi** giấy phép con: chụp ảnh không phải ngành nghề có điều kiện **[CHƯA XN]**.
- Kết quả: có con dấu Studio, tối đa 30 thợ, và nhận tiền vào **tài khoản công ty** (tên chủ tài khoản phải khớp tên doanh nghiệp).

**Liên kết với giải ngân (NAPAS)**: tra tên chủ tài khoản qua NAPAS thường chỉ trả **tên đã che** (ví dụ "N*** V** A**") và kết quả khớp hoàn toàn / gần đúng / không xác minh được. Một số ngân hàng không hỗ trợ **[XN, tài liệu Airwallex]**. Muốn dùng thì phải qua cổng thanh toán hoặc ngân hàng đối tác, chẳng hạn API "chi hộ" sau này. Quy tắc đề xuất: so tên đã bỏ dấu và chuẩn hoá. Khớp thì tự duyệt; gần khớp thì staff duyệt; không khớp hoặc không xác minh được thì giữ tiền ở `on_hold`. Shopee đã yêu cầu tài khoản ngân hàng "khớp 100%" với CCCD từ 8/7/2026 **[TC]**.

---

## (E) Bảo vệ dữ liệu cá nhân

| Được lưu (tối thiểu cần thiết) | Không lưu |
|---|---|
| Trạng thái, phương thức, mã giao dịch của nhà cung cấp, thời điểm, phiên bản điều khoản đã đồng ý | Ảnh selfie, video liveness, template khuôn mặt (để nhà cung cấp xử lý; chỉ nhận kết quả khớp hoặc không) |
| Họ tên pháp lý và ngày sinh (🔒, chỉ server, giống `payoutAccounts`) | Ảnh trong chip, toàn bộ dữ liệu chip (quê quán, nơi thường trú, dân tộc, tôn giáo, đặc điểm nhận dạng) |
| Số định danh: **mã hoá** (vì cần cho thuế), cùng **HMAC** để chặn trùng tài khoản và 4 số cuối để hiển thị | Ảnh CCCD sau khi duyệt thủ công. Giữ tối đa 30 ngày như spec, đề xuất rút xuống 7 ngày. |
| Cờ `age18Plus` | Bất cứ thứ gì trên tài liệu `users/{uid}` công khai |

Nghĩa vụ:
- Đồng ý riêng, rõ mục đích ("xác minh để nhận đơn và nộp thuế thay"), không gộp chung với điều khoản chung **[XN về nguyên tắc]**.
- Lập hồ sơ đánh giá tác động xử lý dữ liệu. Doanh nghiệp xử lý dữ liệu nhạy cảm thì **không được miễn** **[XN]**.
- Firebase ở `asia-southeast1` (Singapore) nghĩa là **chuyển dữ liệu ra nước ngoài**, phải có hồ sơ đánh giá tác động chuyển dữ liệu ra nước ngoài (Nghị định 356, mẫu 09) **[TC]**.
- Xoá dữ liệu theo yêu cầu trong 20 ngày **[TC]**.
- Mức phạt tối đa 5% doanh thu năm trước **[XN]**.

---

## (F) Rủi ro và câu hỏi mở cho chủ sản phẩm

1. App có phải "nền tảng TMĐT trung gian" theo Luật 122/2025 không? Nếu có thì bắt buộc xác thực danh tính từ 01/01/2027, và phải khấu trừ thuế theo Nghị định 117/2025. **Cần luật sư.**
2. Tách `identityVerified` (cổng nhận đơn) với tích xanh (thành tích)? Hay gộp làm một và bỏ ngưỡng "≥ 3 buổi"? Thợ chưa làm buổi nào sẽ không bao giờ có buổi thứ nhất nếu không được nhận đơn khi chưa có tích.
3. Ký RAR trực tiếp hay qua bên trung gian? Cần pháp nhân, ngân sách, thời gian. Hỏi báo giá trước quý 1/2027.
4. Có cho duyệt thủ công (ảnh CCCD) khi máy không có NFC và người dùng không có VNeID mức 2 không? Từ 2027 có thể không còn hợp lệ.
5. Thu phí xác minh không (câu hỏi mở 23)? Đề xuất **miễn phí**: chi phí mỗi lượt thấp và đây là nghĩa vụ của sàn.
6. Studio chưa xác minh doanh nghiệp có được nhận đơn với danh nghĩa chủ studio (giới hạn 3 thợ) không? Đề xuất: được.
7. Thay đổi data model: `photographers.identityStatus`, collection 🔒 `identity_records`, cùng chỉ mục unique theo HMAC số định danh (một người một tài khoản nhà cung cấp).

---

## (G) Nguồn (truy cập 2026-10-06)

- CAND, "Trung tâm RAR là đơn vị duy nhất… cấp phép cung cấp dịch vụ xác thực điện tử" (15/8/2024): https://cand.vn/hoat-dong-ll-cand/trung-tam-rar-la-don-vi-duy-nhat-cua-bo-cong-an-duoc-cap-phep-cung-cap-dich-vu-xac-thuc-dien-tu-i740612/
- Thanh Tra, 9Pay ký với RAR (13/7/2025): https://thanhtra.com.vn/thong-tin-doanh-nghiep-49F64E63D/9pay-ky-ket-voi-trung-tam-rar-trien-khai-dich-vu-xac-thuc-dien-tu-qua-vneid-tren-ung-dung-9pay-02398d392.html
- Tuổi Trẻ, VNeID trong chứng khoán (7/8/2025): https://tuoitre.vn/bo-cong-an-ky-ket-dich-vu-xac-thuc-dien-tu-qua-vneid-trong-giao-dich-chung-khoan-20250807185627091.htm
- VNDirect, hướng dẫn xác thực qua VNeID: https://support.vndirect.com.vn/hc/vi/articles/50366406088345
- Nghị định 69/2024, chương 3: https://hethongphapluat.com/nghi-dinh-69-2024-nd-cp-quy-dinh-ve-dinh-danh-va-xac-thuc-dien-tu/chuong-3
- VietQR/GTEL, tài liệu eKYC VNeID (mTLS): https://doc.vietqr.vn/doc/hoa-don-vat-tu-dong/ekyc-xac-thuc-vneid
- V9 VNeID: https://v9.com.vn/v9-vneid-giai-phap-xac-thuc-dinh-danh/
- VNPT IDCheck: https://ekyc.vnpt.vn/en/idcheck · VNPT ID Check: https://vnpt.vn/doanh-nghiep/san-pham-dich-vu/dich-vu-xac-thuc-thong-tin-cccd-gan-chip-vnpt-id-check/ · Bảng giá: https://vnpt-dongnai.com/gia-vnpt-ekyc.html
- FPT.AI SDK: https://docs.fpt.ai/docs/vi/vision/documentation/sdk-ekyc/ · TrustingSocial Flutter: https://ekyc.trustingsocial.com/api-docs/ekyc-platform-api/sdk-integration/flutter-v4.x.x
- Luật BVDLCN và Nghị định 356/2025: https://www.vcci.com.vn/tin-tuc/luat-bao-ve-du-lieu-ca-nhan-luu-y-ve-hanh-lang-phap-ly-moi-cho-doanh-nghiep · https://luatvietan.vn/diem-moi-cua-nghi-dinh-356-2025-so-voi-nghi-dinh-13-2023-ve-huong-dan-bao-ve-du-lieu-ca-nhan.html
- Luật TMĐT 122/2025 và Nghị định 248/2026: https://vnexpress.net/nguoi-livestream-ban-hang-phai-xac-thuc-danh-tinh-theo-vneid-4992047.html · https://hethongphapluat.com/nghi-dinh-248-2026-nd-cp-huong-dan-luat-thuong-mai-dien-tu.html · https://luatvietnam.vn/tin-van-ban-moi/da-co-nghi-dinh-248-2026-nd-cp-huong-dan-thi-hanh-luat-thuong-mai-dien-tu-tu-01-7-2026-186-110111-article.html · https://moit.gov.vn/tin-tuc/bo-cong-thuong-pho-bien-luat-thuong-mai-dien-tu-va-nghi-dinh-so-248-2026-nd-cp.html
- Các sàn siết định danh người bán (6/7/2026): https://thegioitiepthi.danviet.vn/vi-sao-shopee-tiktok-shop-lazada-dong-loat-siet-dinh-danh-nguoi-ban-d1440928.html
- Số định danh thay mã số thuế: https://thoibaotaichinhvietnam.vn/tu-172025-su-dung-so-dinh-danh-ca-nhan-thay-cho-ma-so-thue-167495.html · Nghị định 117/2025: https://lsvn.vn/san-thuong-mai-dien-tu-phai-khau-tru-va-nop-thue-thay-cho-ho-ca-nhan-kinh-doanh-a170137.html
- Tra cứu doanh nghiệp: https://dangkykinhdoanh.gov.vn · https://api.vietqr.io/v2/business/0100109106
- NAPAS tra tên chủ tài khoản (Airwallex): https://www.airwallex.com/docs/payouts/beneficiaries/verify-a-beneficiary-account/viet-nam
- Airbnb xác minh danh tính chủ nhà: https://www.airbnb.com/help/article/1237 · Grab, hồ sơ tài xế: https://www.grab.com/vn/driver/bike/
