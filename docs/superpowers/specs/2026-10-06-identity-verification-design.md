# Xác minh để nhận đơn (S21)

Ngày: 2026-10-06 · Trạng thái: chờ duyệt · Thay: S21.02 "Xin dấu tích xanh" và §3d.1, §3i.4 (điều kiện dấu tích), câu hỏi mở 23 của spec chính `2026-10-01-remaining-screens.md`. Nghiên cứu nền: [`docs/research/2026-10-06-identity-vneid.md`](../../research/2026-10-06-identity-vneid.md).

## 1. Mục tiêu

Chỉ người đã xác minh danh tính thật mới nhận đơn và nhận tiền. Việc xác minh **chỉ xuất hiện khi người dùng muốn nhận đơn**, đi từng bước, mỗi màn hỏi một thứ, không nhắc dồn dập.

Căn cứ: Luật Thương mại điện tử 122/2025 (Điều 17) và Nghị định 248/2026 (Điều 18) yêu cầu sàn trung gian xác thực điện tử danh tính người bán trước khi cho hoạt động, áp dụng từ 01/01/2027. App có thuộc phạm vi hay không cần luật sư xác nhận (§11); thiết kế này đáp ứng sẵn.

## 2. Quyết định đã chốt

| # | Quyết định |
|---|---|
| V1 | Xác minh danh tính bằng **VNeID** (mặc định); không dùng được thì **quét chip CCCD qua NFC + selfie kiểm tra người thật**. Code đi qua cổng `IdentityVerifier` để đổi nhà cung cấp không sửa app. |
| V2 | Chưa xác minh vẫn làm hồ sơ, đăng portfolio, tạo gói, nhắn tin hỏi đáp. Xác minh mở khi bấm **"Bắt đầu nhận đơn"**; xong mới được đặt lịch, báo giá, được studio giao việc. |
| V3 | Xác minh có **phí** (thợ 99.000đ, studio 299.000đ), gồm kiểm tra tự động và **staff duyệt trong 24 giờ**. Phí không hoàn; bị từ chối được gửi lại miễn phí 1 lần. |
| V4 | Được duyệt thì có **dấu tích xanh** ngay. Bỏ điều kiện "≥ 3 buổi `completed`" cũ. |
| V5 | Studio: chủ studio xác minh danh tính là nhận đơn được (tối đa 3 thợ). **Xác minh doanh nghiệp** là bước sau, không tính thêm phí, mở: con dấu Studio, tới 30 thợ, tài khoản nhận tiền đứng tên doanh nghiệp. |
| V6 | Thành viên studio tự xác minh với mức phí của thợ; studio chỉ giao việc cho thành viên đã xác minh. |
| V7 | Tài khoản nhận tiền chỉ hỏi ở lần chi đầu tiên (spec thanh toán §6). |

## 3. Trạng thái

`photographers/{uid}` (công khai): `verified: bool`, `verifiedAt?`, `acceptingOrders: bool` (= `verified` và hồ sơ đủ để đặt). Chỉ server ghi.

`users/{uid}/private/verification` (chỉ chủ tài khoản đọc, chỉ server ghi):

| Trường | Ghi chú |
|---|---|
| `status` | `not_started` · `in_progress` · `submitted` · `approved` · `rejected` · `revoked` |
| `steps` | `{phone: done?, fee: {paymentId, paidAt}?, identity: {method: vneid \| nfc, checkedAt, result: passed \| failed}?, rules: {acceptedAt, version}?}` |
| `submittedAt`, `decidedAt`, `decidedBy`, `rejectReason?` (mã + chữ), `freeResubmitsLeft` (1) | |
| `kind` | `individual` \| `studio` (quyết định mức phí) |

`users/{uid}/private/identity` (chỉ server đọc/ghi; staff xem qua S23.04): `legalName`, `dob`, `gender?`, `idNumberEnc` (mã hoá bằng KMS), `idHash` (HMAC có khoá bí mật), `method`, `provider`, `providerRef`, `verifiedAt`. **Không lưu** ảnh selfie, video kiểm tra người thật, dữ liệu chip thô.

`identity_hashes/{idHash}` → `uid`: một số định danh chỉ gắn với một tài khoản nhận đơn. Trùng → `identity_in_use`, staff xem.

Xác minh doanh nghiệp: `photographers/{uid}.businessVerified: bool` (công khai, quyết định con dấu Studio) và `users/{uid}/private/business` (`taxCode`, `name`, `address`, `status`, `kind: company \| household`, `registrationDocPath?`, `representativeMatched: bool`).

## 4. Luồng

Điểm vào **"Bắt đầu nhận đơn"**: S06.02 (Công việc trống), hồ sơ của chính mình (S03.01, chế độ chủ hồ sơ), S09.02 Cài đặt. Khách mở hồ sơ thợ chưa nhận đơn thấy nhãn "Chưa nhận đơn", vẫn nhắn hỏi được; nút đặt lịch và mời báo giá không có. Thợ chưa nhận đơn không hiện trong S02.06 Tìm thợ (bài đăng vẫn hiện trên feed).

**S21.02 Bắt đầu nhận đơn**: danh sách 4 bước, mỗi bước một màn, làm lúc nào cũng được, tiến độ lưu ở `steps`. Nút chính "Tiếp tục" mở bước đầu chưa xong.

1. **Số điện thoại** (S21.01, OTP). Đã `phoneVerified` thì tự đánh dấu xong.
2. **Phí xác minh**: màn nêu những gì nhận được (dấu tích xanh, nhận đơn và báo giá, staff duyệt trong 24 giờ), mức phí, "Phí không hoàn vì chi phí kiểm tra đã phát sinh; bị từ chối được gửi lại miễn phí 1 lần". Trả bằng VietQR hoặc ví (spec thanh toán §3). Đây là **doanh thu của nền tảng**, thu vào tài khoản của nền tảng, tách khỏi tiền giữ hộ, xuất hoá đơn điện tử (spec thanh toán §8).
3. **Danh tính** (S21.03):
   - Màn đồng ý ngắn: thu họ tên, ngày sinh, số định danh, giới tính; dùng để xác minh, chống trùng tài khoản, khấu trừ thuế; không lưu ảnh selfie.
   - Nút chính **"Xác minh bằng VNeID"**: app gửi yêu cầu qua nhà cung cấp, người dùng đồng ý trong app VNeID và nhập PIN, quay lại app. Không gõ gì.
   - Liên kết **"Không dùng được VNeID? Quét chip CCCD"** (S21.03 biến thể NFC): bước 1/2 áp CCCD vào điện thoại; bước 2/2 selfie 3–5 giây.
   - Kết quả: chỉ hiện họ tên đã che bớt để xác nhận ("NGUYỄN M** T**"). Dưới 18 tuổi → không nhận đơn được (`underage`). Thất bại được thử lại; quá 3 lần trong ngày thì khoá tới hôm sau.
4. **Đồng ý quy định nhận việc**: 5 dòng tóm tắt (tiền giữ theo mốc, bàn giao hai lớp, huỷ và hoàn tiền, khấu trừ thuế với cá nhân, dữ liệu danh tính) lấy từ `docs/legal/terms-and-help-notes.md`, liên kết tới điều khoản đầy đủ, một ô đồng ý (`rules.version` ghi phiên bản). Nút chính **"Gửi duyệt"** → `submitted`.

**Chờ duyệt** (S21.02 trạng thái chờ): dòng thời gian 4 mốc, "trong 24 giờ"; người dùng vẫn sửa hồ sơ, portfolio được.

**Staff duyệt** (S23.04): xem kết quả kiểm tra tự động, họ tên/ngày sinh (không thấy số định danh đầy đủ, chỉ 4 số cuối), ảnh đại diện, vài ảnh portfolio, cảnh báo trùng. Quyết định:
- **Duyệt** → `approved`, `verified = true`, `acceptingOrders` theo hồ sơ, thông báo "Bạn đã có thể nhận đơn".
- **Từ chối** kèm mã lý do (`fake_avatar`, `stolen_portfolio`, `identity_mismatch`, `duplicate_account`, `underage`, `other` + chữ) → `rejected`; người dùng thấy lý do cụ thể và nút "Sửa và gửi lại" khi `freeResubmitsLeft > 0`; hết lượt thì gửi lại cần trả phí mới.
- Quá 24 giờ chưa duyệt: báo staff (hàng đợi đỏ); không tự duyệt.

**Thu hồi** (`revoked`): staff thu hồi khi phát hiện gian lận sau này; tắt nhận đơn, ẩn dấu tích; booking đang chạy xử lý theo khiếu nại (S18), không tự huỷ.

**Nhắc**: bỏ dở thì gửi **một** thông báo sau 24 giờ và một banner có thể tắt ở S06.01. Không nhắc thêm, không email.

## 5. Xác minh doanh nghiệp cho studio (S21.04)

- Mở khi studio cần: chạm giới hạn 3 thợ ở S26.01, xin con dấu Studio, hoặc thêm tài khoản nhận tiền đứng tên doanh nghiệp. Không có trong S21.02.
- Studio nhập **mã số thuế**; app tra tên, địa chỉ, tình trạng (nguồn tra cứu chọn trong plan; ứng viên ở nghiên cứu §D).
- **Hộ kinh doanh**: mã số thuế là số định danh của chủ → so `idHash` với chủ studio, khớp thì tự duyệt.
- **Công ty**: tải ảnh giấy đăng ký kinh doanh; staff đối chiếu người đại diện với danh tính chủ studio ở S23.04.
- Tình trạng không "Đang hoạt động" → không duyệt.
- Không thu thêm phí (đã gồm trong 299.000đ).

## 6. Cổng `IdentityVerifier`

`packages/domain`: cổng `IdentityVerifier { start(uid, method) → session; result(sessionId) → {passed, legalName, dob, gender, idNumber} }` và luật (tuổi, trùng, khoá thử lại, trạng thái). Bản cài đặt:

| Bản | Dùng khi |
|---|---|
| `FakeIdentityVerifier` | emulator, dev, test: kết quả theo seed |
| `VneidVerifier` | qua Trung tâm RAR (C06) trực tiếp hoặc đơn vị trung gian đã kết nối RAR |
| `ChipEkycVerifier` | NFC + selfie qua nhà cung cấp eKYC có đối chiếu C06; SDK native bọc bằng platform channel nếu không có SDK Flutter |

Cloud Functions chỉ là adapter (callable `startIdentityVerification`, webhook kết quả nếu nhà cung cấp gửi về). Nhà cung cấp thường đòi IP ra cố định và mTLS: cần Cloud NAT cho Functions (kiểm lại với nhà cung cấp).

Callable khác: `submitVerification`, `reviewVerification` (staff), `revokeVerification` (staff), `verifyBusiness`.

## 7. Server chặn ở đâu

`acceptingOrders`/`verified` được kiểm tra trên server ở: tạo booking (`createBookingDraft`, Chụp ngay), gửi báo giá, mời báo giá, `assignBooking` (thành viên phải đã xác minh), chi trả (tài khoản nhận tiền phải khớp danh tính, spec thanh toán §6). Rules: client không ghi được các trường này.

## 8. Màn hình

| Mã | Màn | Route | Ai |
|---|---|---|---|
| S21.01 | Xác minh số điện thoại (OTP) | `/verify/phone` | cả hai (giữ) |
| S21.02 | **Bắt đầu nhận đơn**: danh sách bước, phí, chờ duyệt, bị từ chối | `/verify/start` | thợ, studio |
| S21.03 | Xác minh danh tính (VNeID / chip CCCD) | `/verify/identity` | thợ, studio |
| S21.04 | Xác minh doanh nghiệp | `/verify/business` | studio |
| S23.04 | Duyệt xác minh (đổi tên từ "Duyệt xác minh nhiếp ảnh gia (dấu tích xanh)") | nội bộ | admin |

Thay đổi màn cũ: S06.02 (nút chính "Bắt đầu nhận đơn"), S03.01 (nhãn "Chưa nhận đơn" khi khách xem; chủ hồ sơ thấy thẻ "Còn {n} bước để nhận đơn"), S09.02 (dòng "Xác minh & nhận đơn"), S26.01 (giới hạn 3 thợ dẫn tới S21.04).

## 9. Dữ liệu cá nhân

- Luật Bảo vệ dữ liệu cá nhân 91/2025 và Nghị định 356/2025 (thay Nghị định 13/2023 từ 01/01/2026): ảnh khuôn mặt là dữ liệu nhạy cảm; app không tự lưu nhưng vẫn xử lý qua nhà cung cấp, nên **phải lập hồ sơ đánh giá tác động**. Lưu trên Firebase ở Singapore là chuyển dữ liệu ra nước ngoài: cần hồ sơ riêng hoặc chuyển dữ liệu danh tính về máy chủ trong nước (câu hỏi mở).
- Tối thiểu hoá: chỉ lưu các trường ở §3; số định danh mã hoá, mã băm có khoá; staff chỉ thấy 4 số cuối.
- Xoá tài khoản (S22.02): xoá `identity`, giữ `idHash` trong thời hạn luật thuế yêu cầu (cần kế toán xác nhận) để chống tạo lại tài khoản gian lận.

## 10. Kiểm thử

- Domain: chuyển trạng thái; phí theo `kind`; lượt gửi lại; tuổi; trùng `idHash`; khoá thử lại 3 lần/ngày; studio hộ kinh doanh tự khớp.
- Rules: client không đọc `identity`, không ghi `verified`/`acceptingOrders`/`verification`.
- Functions: `FakeIdentityVerifier`; chặn tạo booking/báo giá/giao việc khi chưa xác minh; webhook idempotent.
- App: S21.02 các trạng thái (từng bước, chờ, bị từ chối, đã duyệt), S21.03 hai cách, S21.04, thẻ "Còn n bước", nhãn "Chưa nhận đơn".

## 11. Câu hỏi mở

1. Luật sư: app có là "nền tảng TMĐT trung gian" theo Luật 122/2025 không; quét chip CCCD có đạt "xác thực điện tử" khi chưa có VNeID không.
2. Báo giá và thời gian đăng ký với Trung tâm RAR hoặc đơn vị trung gian (VNPT, GTEL…); nhà cung cấp eKYC chip CCCD.
3. Lưu dữ liệu danh tính ở Singapore hay máy chủ trong nước.
4. Kế toán: hoá đơn điện tử cho phí xác minh; thời hạn giữ `idHash` sau khi xoá tài khoản.

## 12. Chia việc

1. Domain + Functions + rules: trạng thái, cổng `IdentityVerifier` (bản giả), chặn ở §7, staff duyệt.
2. App: S21.02, S21.03, S21.04, thay đổi S06.02, S03.01, S09.02, S26.01.
3. Bản cài đặt thật (VNeID, chip CCCD) sau khi có hợp đồng.
