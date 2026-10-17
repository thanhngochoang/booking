# Xác minh để nhận đơn (S21)

Ngày: 2026-10-06 · Trạng thái: #135 đã làm (ba bước, danh tính và mã số thuế giả lập, staff duyệt bằng CLI); #203 đã làm (bước phí xác minh trên thanh toán dùng chung, cờ phí bật ở server và app); bản cài đặt thật còn lại (§6) · Thay: S21.02 "Xin dấu tích xanh" và §3d.1, §3i.4 (điều kiện dấu tích), câu hỏi mở 23 của spec chính `2026-10-01-remaining-screens.md`. Nghiên cứu nền: [`docs/research/2026-10-06-identity-vneid.md`](../../research/2026-10-06-identity-vneid.md).

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

`verifications/{uid}` (cấp cao nhất, chủ tài khoản đọc, chỉ server ghi; **đổi 2026-10-08, #135**: spec cũ để ở `users/{uid}/private/verification`, nhưng staff cần truy vấn hàng đợi (`status == 'submitted'`, `business.status == 'submitted'`, nhắc) và truy vấn collection-group trên `private` sẽ lẫn `contact`, `inbox`, `business` có cùng tên trường):

| Trường | Ghi chú |
|---|---|
| `status` | `not_started` · `in_progress` · `submitted` · `approved` · `rejected` · `revoked` |
| `steps` | `{phone: done?, fee: {paymentId, amount, paidAt}?, identity: {method: vneid \| nfc, checkedAt, result: passed \| failed}?, rules: {acceptedAt, version}?}` |
| `submittedAt`, `decidedAt`, `decidedBy`, `rejectReason?` (mã + chữ), `freeResubmitsLeft` (1) | |
| `kind` | `individual` \| `studio` (quyết định mức phí); suy lại từ `providerType` mỗi lần ghi cho tới khi bước phí xong (nghệ sĩ NAG trả mức cá nhân) |
| `identitySession`, `identityAttempts` `{dayKey, count}`, `feeAttempt` (1), `nudgedAt?`, `version` | Phiên VNeID/chip đang chờ; số lần bắt đầu xác minh trong ngày VN; lần trả phí (tăng khi gửi lại sau khi hết lượt miễn phí, mục 2 của §4); mốc đã nhắc (một lần); số phiên bản của bản ghi |
| `steps.identity` | thêm `failure?` (`underage` \| `identity_in_use` \| `provider_failed`) và `maskedName` (họ tên đã che, ví dụ "NGUYỄN M** T**": từ đầu giữ nguyên, mỗi từ sau chỉ chữ cái đầu + `**`); bản ghi này là chỗ **duy nhất** chủ tài khoản thấy tên, họ tên đầy đủ không nằm ở đây |
| `steps.fee` | `null` cho tới khi phí được ghi; bộ xử lý `verification_fee` ghi `{paymentId, amount, paidAt}` khi khoản thanh toán xong (#203). Bản ghi gửi duyệt trước #203 giữ `null` (xem "Miễn phí cho bản ghi cũ" ở mục 2 của §4) |
| `business` | nhánh doanh nghiệp (S21.04), xem cuối mục |

`users/{uid}/private/identity` (chỉ server đọc/ghi, rules chặn cả chủ tài khoản đọc; staff xem qua S23.04; còn trong `private` vì chỉ truy cập theo uid): `legalName`, `dob`, `gender?`, `idNumberEnc` (mã hoá bằng KMS), `idHash` (HMAC có khoá bí mật), `method`, `provider`, `providerRef`, `verifiedAt`. **Không lưu** ảnh selfie, video kiểm tra người thật, dữ liệu chip thô.

`identity_hashes/{idHash}` → `uid`: một số định danh chỉ gắn với một tài khoản nhận đơn; tạo trong cùng giao dịch với `private/identity`. Trùng → `identity_in_use`, và một dòng nhật ký ghi uid kia cho staff.

`verificationAudit/{id}` (chỉ server): mỗi quyết định của staff một dòng `{uid, target: identity \| business, action, reason?, note?, actorId, at}` (trùng danh tính thêm `otherUid`). `fake_identities/{uid}` (chỉ server): kết quả giả lập cho emulator và dev (§6).

Xác minh doanh nghiệp: `photographers/{uid}.businessVerified: bool` (công khai, quyết định con dấu Studio) và nhánh `verifications/{uid}.business` (**đổi 2026-10-08, #135**: spec cũ để ở `users/{uid}/private/business`; mã số thuế công ty và tên là dữ liệu đăng ký công khai nên không cần riêng tư hơn; **ngoại lệ hộ kinh doanh**: mã số thuế 12 số chính là số định danh cá nhân của chủ, và #135 hiện lưu nó dạng rõ ở `business.taxCode`, chỉ chủ tài khoản đọc; xem câu hỏi mở 9): `status` (`submitted` \| `approved` \| `rejected`), `kind: company \| household`, `taxCode`, `name`, `address`, `registryStatus` (`active` \| `inactive`), `docPath?` (ảnh giấy đăng ký ở `businessDocs/{uid}/{ulid}.jpg`), `representativeMatched: bool`, `submittedAt`, `decidedAt?`, `decidedBy?`, `rejectReason?` (`inactive`, `representative_mismatch`, `doc_unreadable`, `other`), `purgeAfter?` (30 ngày sau quyết định).

## 4. Luồng

Điểm vào **"Bắt đầu nhận đơn"**: S06.02 (Công việc trống), hồ sơ của chính mình (S03.01, chế độ chủ hồ sơ), S09.02 Cài đặt. Khách mở hồ sơ thợ chưa nhận đơn thấy nhãn "Chưa nhận đơn", vẫn nhắn hỏi được; nút đặt lịch và mời báo giá không có. Thợ chưa nhận đơn không hiện trong S02.06 Tìm thợ (bài đăng vẫn hiện trên feed).

**S21.02 Bắt đầu nhận đơn**: danh sách 4 bước, mỗi bước một màn, làm lúc nào cũng được, tiến độ lưu ở `steps`. Nút chính "Tiếp tục" mở bước đầu chưa xong. Bốn bước theo thứ tự số điện thoại, phí, danh tính, quy định; bộ đếm "{n} / {total}" có `total` = 4. #203 bật cờ `feeRequired` ở cả server (`liveVerificationDeps()`) lẫn app (`verificationFeeRequiredProvider`) **trong cùng một PR**, để một bản phát hành không bao giờ lệch nhau. Khi cờ tắt (cấu hình của #135): danh sách 3 bước, `total` = 3, danh tính không cần phí, `steps.fee` là `null`, không có thanh toán, và lần gửi lại khi hết lượt miễn phí vẫn miễn phí (về thẳng `submitted`, `freeResubmitsLeft` giữ 0). Khi cờ bật, danh tính cần phí đã trả trước (phí kiểm tra của nhà cung cấp tốn tiền; server trả `not_eligible` cho `startIdentityVerification` cho tới khi có phí) và hết lượt miễn phí thì chuyển `in_progress`, xoá bước phí, tăng `feeAttempt`.

1. **Số điện thoại** (S21.01, OTP). Đã `phoneVerified` thì tự đánh dấu xong.
2. **Phí xác minh** (S21.02 bước 2, màn `VerifyFeeScreen` ở `/verify/start/fee`; **đã làm trong #203**): màn nêu những gì nhận được ("Tích xanh cạnh tên trên hồ sơ", "Nhận đơn đặt lịch và gửi báo giá", "Staff duyệt trong 24 giờ"), mức phí và ghi chú "Phí không hoàn vì chi phí kiểm tra đã phát sinh; bị từ chối được gửi lại miễn phí 1 lần.". Nút chính "Thanh toán {amount}" mở S04.04 với chủ thể `VerificationFeePay` (`/verify/start/fee/pay`); trả xong thì quay về S21.02 (app đóng S04.04 bằng pop, chỉ dùng `go` khi S21.02 không còn trong ngăn xếp) và hiện "Đã nhận phí xác minh", **không tự mở S21.03**: dòng danh tính chuyển "Đang làm" và "Tiếp tục" mở nó.
   - **Mức phí** theo `kind`: thợ ảnh cá nhân 99.000₫ (nghệ sĩ NAG cũng trả mức này), studio 299.000₫. `kind` suy lại từ `providerType` mỗi lần ghi cho tới khi phí được ghi, rồi bị cố định (đổi loại thợ sau đó không thu thêm; xem câu hỏi mở 6).
   - **Thanh toán dùng chung (V1, #200)**: phí là một `Payment` có `subjectType = verification_fee`, `subjectId` = `payerId` = uid, người nhận là `PLATFORM_PAYEE` (không bao giờ vào thu nhập hay lô chi trả). Callable `startVerificationFee {method: bank_qr | momo | zalopay, renew?}` trả `PaymentInstructions` của V1 (VietQR cho `bank_qr`, `payUrl` cho ví); chạm lần hai cùng phương thức dùng lại mã còn hạn, `renew` hết hạn mã cũ và cấp mã mới ("Tạo QR mới"). Khoá chống trùng gửi sang cổng là `vfee_{uid}_{feeAttempt}_{method}` cho mã đầu và thêm hậu tố `_{n}` cho mã thứ n của cùng lần trả và cùng phương thức. Callable `checkVerificationFee` hỏi lại cổng và trả `{paid, instructions}`. Khi cổng thanh toán tắt (`!checkoutGatewayAvailable`), `startVerificationFee` trả `not_eligible` trước khi đọc hay ghi gì.
   - **Ghi phí**: tiền chỉ vào qua bộ xử lý `VerificationFeeSettler` (cùng đường webhook, quét 5 phút và `confirmFakePayment` như mọi chủ thể). Khi đủ tiền và phí hợp lệ, một giao dịch: `Payment` giữ `status = paid` và ghi `escrowStatus = released` ngay (doanh thu nền tảng, không có gì để giữ), ghi bút toán `fee_charged` và `steps.fee = {paymentId, amount, paidAt}`; bản ghi `not_started` chuyển `in_progress`. Phí vẫn là **doanh thu của nền tảng**, tách khỏi tiền giữ hộ, xuất hoá đơn điện tử (spec thanh toán §8).
   - **Hoàn tiền** (ngoại lệ duy nhất của "không hoàn", gửi qua V2). Hai lý do riêng của chủ thể này hoàn **100%** khoản đã trả: `duplicate_verification_fee` khi bản ghi đã có phí (trả lần hai, hai phương thức cùng lúc); `stale_verification_fee` khi khoản trả không còn là phí của bản ghi: mã cho mức phí của `kind` cũ, mã của lần trả (`feeAttempt`) trước, bản ghi không còn nhận phí (đã qua các bước, bị từ chối cuối cùng, được miễn phí, hoặc không còn bản ghi). Các trường hợp khác theo quy tắc chung như mọi chủ thể, không phải 100%: chuyển thừa chỉ hoàn phần dư (`overpaid_excess`), chuyển muộn hoàn đúng khoản vừa chuyển (`late_transfer`), chuyển thiếu rồi mã hết hạn hoàn phần đã nhận (`underpaid_expired`).
   - **Không thu phí cho từ chối cuối cùng** (`feePayable`): `startVerificationFee` trả `not_eligible` khi `steps.fee` đã có, phí được miễn, hoặc bản ghi `rejected` với lý do không gửi lại được (`underage`, `duplicate_account`).
   - **Gửi lại có phí**: hết lượt miễn phí thì `resubmitVerification` đưa bản ghi về `in_progress`, xoá `steps.fee`, tăng `feeAttempt`, và phải trả phí mới rồi "Gửi duyệt". Nếu bản ghi bị từ chối từ trước #203 trả phí khi còn `rejected`, khoản đó (`steps.fee.paidAt` sau `decidedAt`) chính là lần gửi lại có phí: gửi lại đi thẳng `submitted`, giữ phí, không tăng `feeAttempt`.
   - **Miễn phí cho bản ghi cũ** (`feeWaived`, Decision 24: bản ghi gửi trước #203 giữ trạng thái): bản ghi `rejected`, còn lượt miễn phí, đã có `submittedAt` mà `steps.fee` là `null` thì bước phí tính là đã xong (mọi lần gửi duyệt của #203 đều có phí, và gửi lại có phí xoá `submittedAt`, nên dấu hiệu này chỉ khớp bản ghi cũ). Lần gửi lại miễn phí đó không cần phí, `startVerificationFee` từ chối, và `startIdentityVerification` cũng tính bước phí là xong (từ chối `identity_mismatch` xoá bước danh tính nên người dùng vẫn xác minh lại được mà không trả). Hết lượt miễn phí rồi bị từ chối lần nữa thì phí được yêu cầu bình thường. **Lưu ý khi bật tắt cờ**: tắt `feeRequired` rồi bật lại cũng làm mọi bản ghi được gửi duyệt trong lúc cờ tắt (không có `steps.fee`) hưởng cùng miễn phí khi bị từ chối còn lượt miễn phí. Chi phí nếu sai: những thợ đó bỏ qua một lần phí 99.000₫ hoặc 299.000₫.
3. **Danh tính** (S21.03):
   - Màn đồng ý ngắn: thu họ tên, ngày sinh, số định danh, giới tính; dùng để xác minh, chống trùng tài khoản, khấu trừ thuế; không lưu ảnh selfie.
   - Nút chính **"Xác minh bằng VNeID"**: app gửi yêu cầu qua nhà cung cấp, người dùng đồng ý trong app VNeID và nhập PIN, quay lại app. Không gõ gì.
   - Liên kết **"Không dùng được VNeID? Quét chip CCCD"** (S21.03 biến thể NFC): bước 1/2 áp CCCD vào điện thoại; bước 2/2 selfie 3–5 giây.
   - Kết quả: chỉ hiện họ tên đã che bớt để xác nhận ("NGUYỄN M** T**"). Dưới 18 tuổi → không nhận đơn được (`underage`). Thất bại được thử lại; mỗi lần bắt đầu tính một lần trong ngày VN, kể cả bỏ dở, và lần bắt đầu thứ 4 bị khoá tới hôm sau.
4. **Đồng ý quy định nhận việc**: 5 dòng tóm tắt (tiền giữ theo mốc, bàn giao hai lớp, huỷ và hoàn tiền, khấu trừ thuế với cá nhân, dữ liệu danh tính) lấy từ `docs/legal/terms-and-help-notes.md`, một ô đồng ý (`rules.version` ghi phiên bản, `PROVIDER_RULES_VERSION = '2026-10-06'`). Chưa có liên kết tới điều khoản đầy đủ vì văn bản điều khoản chưa viết (hoãn tới khi có văn bản). Nút chính **"Gửi duyệt"** → `submitted`.

**Chờ duyệt** (S21.02 trạng thái chờ): dòng thời gian 4 mốc khi có phí đã ghi (mốc đầu "Đã trả phí xác minh · {when} · {amount}"), 3 mốc khi `steps.fee` là `null` (cờ phí tắt hoặc bản ghi cũ), "trong 24 giờ"; người dùng vẫn sửa hồ sơ, portfolio được.

**Staff duyệt** (S23.04): xem kết quả kiểm tra tự động, họ tên/ngày sinh (không thấy số định danh đầy đủ, chỉ 4 số cuối), ảnh đại diện, vài ảnh portfolio, cảnh báo trùng. Quyết định:
- **Duyệt** → `approved`, `verified = true`, `acceptingOrders` theo hồ sơ, thông báo "Bạn đã có thể nhận đơn".
- **Từ chối** kèm mã lý do (`fake_avatar`, `stolen_portfolio`, `identity_mismatch`, `duplicate_account`, `underage`, `other` + chữ) → `rejected`; người dùng thấy lý do cụ thể và nút "Sửa và gửi lại" khi `freeResubmitsLeft > 0`; hết lượt thì gửi lại cần trả phí mới (dòng "Hết lượt gửi lại miễn phí · gửi lại cần trả phí xác minh mới", chỉ hiện khi cờ phí bật; còn lượt thì hiện "Còn 1 lần gửi lại miễn phí").
- Quá 24 giờ chưa duyệt: báo staff (hàng đợi đỏ); không tự duyệt.

**Thu hồi** (`revoked`): staff thu hồi khi phát hiện gian lận sau này; tắt nhận đơn, ẩn dấu tích; booking đang chạy xử lý theo khiếu nại (S18), không tự huỷ.

**Nhắc**: bỏ dở thì gửi **một** thông báo sau 24 giờ (`verification_reminder`, chạy trong `bookingClock`, `nudgedAt` đảm bảo một lần) và một banner có thể tắt ở S06.01. Không nhắc thêm, không email. **Banner S06.01 không làm**: thợ chưa xác minh không có việc nào, họ thấy S06.02 với nút "Bắt đầu nhận đơn".

**Hàng đợi quá hạn**: CLI `list` đánh dấu `!` các hàng chờ quá 24 giờ (`REVIEW_SLA_HOURS`); chưa có job hay thông báo cho staff.

**Staff duyệt bằng CLI tới khi có S23.04 (phase 1.5, #83)**: `npm run verifications -- list | show <uid> | approve <uid> | reject <uid> <lý do> ["ghi chú"] | revoke <uid> "ghi chú" | business-approve <uid> | business-reject <uid> <lý do> ["ghi chú"] --actor <uid>` (uid phải có claim admin) đi qua đúng use case `reviewVerification` và callable cùng tên (`{uid, target: identity | business, action, reason?, note?}`); duyệt ghi `verifications/{uid}` và `photographers/{uid}` (`verified`, `verifiedAt`, `acceptingOrders`) trong **một giao dịch**, thu hồi ghi `verified: false, acceptingOrders: false` cùng cách (booking đang chạy không bị đụng). Lý do từ chối mở lại gì: `fake_avatar` → dòng sửa "Ảnh đại diện" (→ `/settings/profile`); `stolen_portfolio` → dòng "Portfolio" (→ `/u/{uid}`); `identity_mismatch` → xoá bước danh tính, phải xác minh lại; `other` → hiện ghi chú của staff, gửi lại bình thường; `duplicate_account` và `underage` là cuối cùng (không gửi lại, chỉ dòng hỗ trợ). `revoked` là cuối trong app (chỉ hiện trạng thái và email hỗ trợ); khôi phục là câu hỏi mở với chủ sản phẩm (§11).

Hook: `notifyVerificationDecision` (duyệt, từ chối, thu hồi), `notifyBusinessDecision` (doanh nghiệp), `notifyVerificationReminder` trong `packages/domain/src/notification_hooks.ts` (#138); #135 gọi sau khi quyết định được ghi. Cả ba đều mở S21.02 hoặc S21.04, quyết định là thông báo quan trọng.

## 5. Xác minh doanh nghiệp cho studio (S21.04)

- Mở khi studio cần: chạm giới hạn 3 thợ ở S26.01, xin con dấu Studio, hoặc thêm tài khoản nhận tiền đứng tên doanh nghiệp. Không có trong S21.02.
- Studio nhập **mã số thuế** (10 số: công ty; 10 số + `-` + 3 số: chi nhánh, tính là công ty; 12 số: hộ kinh doanh, số định danh cá nhân của chủ từ 01/07/2025); app tra tên, địa chỉ, tình trạng qua cổng `TaxCodeLookup`. **Đã làm (#135)**: chỉ `FakeTaxCodeLookup` (emulator, dev): mã kết thúc `0000` → công ty "CÔNG TY TNHH STUDIO {4 số cuối}" ngừng hoạt động; 12 số → hộ kinh doanh "HỘ KINH DOANH STUDIO THỬ" (trừ mã 12 số kết thúc `0000`: nhánh ngừng hoạt động đi trước nên thành công ty ngừng hoạt động, `not_eligible`); còn lại → công ty "CÔNG TY TNHH STUDIO THỬ {4 số cuối}"; địa chỉ luôn là "12 Nguyễn Huệ, Phường Sài Gòn, TP. Hồ Chí Minh", và hai loại sau đang hoạt động. **Hoãn**: tra thật ứng viên `api.vietqr.io/v2/business/{mst}` (cần ra mạng ngoài, tức gói Blaze; nghiên cứu §D); ngoài emulator/dev callable trả `not_eligible`.
- Chỉ mở với studio đã `verified`. Ngừng hoạt động → `not_eligible`.
- **Hộ kinh doanh**: mã số thuế là số định danh của chủ → so `idHash` của mã số thuế với `idHash` danh tính chủ studio, khớp thì tự duyệt (`businessVerified: true`), không khớp thì từ chối `representative_mismatch`. **Ngoại lệ về lưu trữ**: vì mã số thuế 12 số là số định danh cá nhân, `business.taxCode` của hộ kinh doanh đang lưu **dạng rõ** (chỉ chủ tài khoản đọc), trái với nguyên tắc ở §9 (số định danh mã hoá); #135 giữ nguyên, câu hỏi mở 9 hỏi có nên chỉ lưu băm hoặc 4 số cuối.
- **Công ty**: tải ảnh giấy đăng ký kinh doanh (`businessDocs/{uid}/{ulid}.jpg`, JPEG tới 3 MiB, chỉ tạo mới, ảnh xoá 30 ngày sau quyết định bởi bước thứ hai của job `purgeAwardProofs` hằng ngày); staff đối chiếu người đại diện với danh tính chủ studio (CLI `show` tải ảnh, S23.04 sau). Hộ kinh doanh và công ty gửi lại chỉ khi bản ghi cũ đã bị từ chối.
- Con dấu: `providerMarkOf` có thêm `businessVerified`; studio có tích xanh khi `verified`, con dấu Studio vàng chỉ khi `businessVerified` (V4, V5); nghệ sĩ giữ tích vàng, cá nhân không đổi.
- Tình trạng không "Đang hoạt động" → không duyệt.
- Không thu thêm phí (đã gồm trong 299.000đ).

## 6. Cổng `IdentityVerifier`

`packages/domain`: cổng `IdentityVerifier { start(uid, method) → session; result(sessionId) → {passed, legalName, dob, gender, idNumber} }` và luật (tuổi, trùng, khoá thử lại, trạng thái). Bản cài đặt:

| Bản | Dùng khi |
|---|---|
| `FakeIdentityVerifier` | emulator, dev, test: kết quả theo seed |
| `VneidVerifier` | qua Trung tâm RAR (C06) trực tiếp hoặc đơn vị trung gian đã kết nối RAR |
| `ChipEkycVerifier` | NFC + selfie qua nhà cung cấp eKYC có đối chiếu C06; SDK native bọc bằng platform channel nếu không có SDK Flutter |

**Đã làm (#135)**: chỉ `FakeIdentityVerifier` và hai bản giả đi kèm; `VneidVerifier`, `ChipEkycVerifier` và `TaxCodeLookup` thật là **Hoãn** tới khi có hợp đồng nhà cung cấp.

- `FakeIdentityVerifier` chạy khi `fakePaymentsAllowed()` (emulator hoặc dev): kết quả lấy từ `fake_identities/{uid}` (`{legalName, dob, gender, idNumber, passed}`, do seed hoặc Emulator UI ghi), không có thì họ tên = tên hiển thị bỏ dấu viết hoa (dự phòng "NGUOI DUNG THU"), `dob` 1995-01-01, số định danh = "0" + 11 số từ băm FNV-1a của uid. Ngoài hai môi trường đó các callable danh tính trả `not_eligible`, và app chỉ hiện hai sheet VNeID/NFC giả khi `--dart-define=REAL_IDENTITY` **không** đặt (`identityModeProvider` false).
- Cổng `IdentityVault { hashId, encryptId }`: bản `devIdentityVault` dùng HMAC-SHA256 và AES-256-GCM với khoá dev cố định có ghi nhãn, từ chối chạy ngoài `fakePaymentsAllowed()`. **Hoãn**: vault dùng KMS (cần Secret Manager, chưa có trong plan), nên chưa thể lưu số định danh thật.
- Luật danh tính: dưới 18 tuổi theo ngày VN → `underage`; trùng → `identity_in_use`; nhà cung cấp trả "không đạt" → bước `failed`, callable `not_eligible`. Giới hạn **3 lần mỗi ngày VN** đếm ở `startIdentityVerification`: mỗi lần bắt đầu tính một lần, kể cả bỏ dở; lần bắt đầu thứ 4 trong ngày VN bị `rate_limited` tới ngày hôm sau. Kết quả thất bại (`underage`, `identity_in_use`, `provider_failed`) được ghi trước và lỗi ném sau khi giao dịch xong, để bản ghi thất bại không bị hoàn tác.

Cloud Functions chỉ là adapter (callable `startIdentityVerification`, `completeIdentityVerification`, webhook kết quả nếu nhà cung cấp gửi về). Nhà cung cấp thường đòi IP ra cố định và mTLS: cần Cloud NAT cho Functions (kiểm lại với nhà cung cấp).

Callable đã có (vùng `asia-southeast1`): `confirmPhoneVerified`, `startIdentityVerification`, `completeIdentityVerification`, `acceptVerificationRules`, `submitVerification`, `resubmitVerification`, `lookupTaxCode`, `submitBusinessVerification` và `reviewVerification` (staff, thay cho `revokeVerification` và `verifyBusiness` của bản đầu: một callable với `target` và `action`). Callable phí `startVerificationFee` và `checkVerificationFee` (#203) cùng vùng và cùng bộ khoá bí mật thanh toán; bộ xử lý `verification_fee` được đăng ký ở `liveSettlementDeps()` (thanh toán) và `liveRefundSubjects()` (gửi lại hoàn tiền).

Điện thoại (S21.01): app liên kết số với tài khoản Firebase Auth (`linkWithCredential`, hoặc `updatePhoneNumber` khi đã có số), rồi `confirmPhoneVerified` so số của Auth (Admin SDK) với `contact.phone` và đặt `phoneVerified: true` từ server. Bước này **là** cờ `contact.phoneVerified`; đổi số sẽ đặt lại cờ (rules sẵn có) nên bước hiện chưa xong, còn thợ đã duyệt vẫn giữ trạng thái duyệt (số điện thoại là liên hệ, không phải danh tính).

## 7. Server chặn ở đâu

`acceptingOrders`/`verified` được kiểm tra trên server ở: tạo booking (`createBookingDraft`, Chụp ngay), gửi báo giá, mời báo giá, `assignBooking` (thành viên phải đã xác minh), chi trả (tài khoản nhận tiền phải khớp danh tính, spec thanh toán §6). Rules: client không ghi được các trường này.

Cổng chung là port `ProviderOrderGate` (`packages/domain`, đọc `verified` + `onboardingComplete` của `photographers/{uid}`) và mã lỗi `not_accepting_orders` (Functions: `failed-precondition`); đã dùng ở `createBookingDraft` (#133), các cổng sau (Chụp ngay, báo giá, `assignBooking`) dùng lại chính nó.

Hai chỗ kiểm lại khi tiền đi qua (thêm 2026-10-08): (1) `createPayment` từ chối thợ không còn nhận đơn (`not_accepting_orders`) qua `assertOrderAllowed` của #198; (2) việc kiểm khi **ghi nhận tiền** là của #135: `handleTransferNotification` đọc `acceptsOrders(payment.payeeId)` trong giao dịch (trong `applyTransfer`), sau khi khoản chuyển đã làm khoản thanh toán `paid` và booking vẫn là nháp; nếu `false`, hoàn 100% qua `refundLatePayment` với lý do mới `provider_not_accepting` (thêm vào `PAYMENT_REFUND_REASONS`; `refundLatePayment` có thêm tham số lý do, mặc định `late_payment_draft_expired`) thay vì `moveDraftToRequested`; booking vẫn là nháp và job quét nháp trả ngày. Đây là nơi duy nhất giữ luật này.

## 8. Màn hình

| Mã | Màn | Route | Ai |
|---|---|---|---|
| S21.01 | Xác minh số điện thoại (OTP) | `/verify/phone` | cả hai (giữ) |
| S21.02 | **Bắt đầu nhận đơn**: danh sách bước, phí, chờ duyệt, bị từ chối | `/verify/start` | thợ, studio |
| S21.03 | Xác minh danh tính (VNeID / chip CCCD) | `/verify/identity` | thợ, studio |
| S21.04 | Xác minh doanh nghiệp | `/verify/business` | studio |
| S23.04 | Duyệt xác minh (đổi tên từ "Duyệt xác minh nhiếp ảnh gia (dấu tích xanh)") | nội bộ | admin |

Thay đổi màn cũ: S06.02 (nút chính "Bắt đầu nhận đơn"), S03.01 (nhãn "Chưa nhận đơn" khi khách xem; chủ hồ sơ thấy thẻ "Còn {n} bước để nhận đơn"), S09.02 (dòng "Xác minh & nhận đơn"), S26.01 (giới hạn 3 thợ dẫn tới S21.04).

S09.02: dòng "Xác minh & nhận đơn" (`settings-verify`) có sẵn trong `SettingsScreen` (#148), chỉ hiện khi `verifyStartReadyProvider` (`lib/features/settings/settings_links.dart`) là true; bật khi có `/verify/start` (S21.02), và lúc đó thay phụ đề bằng "Còn {n} bước".

## 9. Dữ liệu cá nhân

- Luật Bảo vệ dữ liệu cá nhân 91/2025 và Nghị định 356/2025 (thay Nghị định 13/2023 từ 01/01/2026): ảnh khuôn mặt là dữ liệu nhạy cảm; app không tự lưu nhưng vẫn xử lý qua nhà cung cấp, nên **phải lập hồ sơ đánh giá tác động**. Lưu trên Firebase ở Singapore là chuyển dữ liệu ra nước ngoài: cần hồ sơ riêng hoặc chuyển dữ liệu danh tính về máy chủ trong nước (câu hỏi mở).
- Tối thiểu hoá: chỉ lưu các trường ở §3; số định danh mã hoá, mã băm có khoá; staff chỉ thấy 4 số cuối.
- Xoá tài khoản (S22.02): xoá `identity`, giữ `idHash` trong thời hạn luật thuế yêu cầu (cần kế toán xác nhận) để chống tạo lại tài khoản gian lận.

## 10. Kiểm thử

- Domain: chuyển trạng thái; phí theo `kind`; lượt gửi lại; tuổi; trùng `idHash`; khoá 3 lần bắt đầu mỗi ngày VN; studio hộ kinh doanh tự khớp.
- Rules: client không đọc `identity`, không ghi `verified`/`acceptingOrders`/`verification`.
- Functions: `FakeIdentityVerifier`; chặn tạo booking/báo giá/giao việc khi chưa xác minh; webhook idempotent.
- App: S21.02 các trạng thái (từng bước, chờ, bị từ chối, đã duyệt), S21.03 hai cách, S21.04, thẻ "Còn n bước", nhãn "Chưa nhận đơn".

## 11. Câu hỏi mở

1. Luật sư: app có là "nền tảng TMĐT trung gian" theo Luật 122/2025 không; quét chip CCCD có đạt "xác thực điện tử" khi chưa có VNeID không.
2. Báo giá và thời gian đăng ký với Trung tâm RAR hoặc đơn vị trung gian (VNPT, GTEL…); nhà cung cấp eKYC chip CCCD.
3. Lưu dữ liệu danh tính ở Singapore hay máy chủ trong nước.
4. Kế toán: hoá đơn điện tử cho phí xác minh; thời hạn giữ `idHash` sau khi xoá tài khoản.
5. **Khách có phải nhập OTP khi đặt (S04.05)?** Chưa: chi phí SMS và quyết định về tiền ngày 2026-10-07; S21.01 hiện chỉ dùng cho thợ (Decision 21 của plan).
6. Đổi loại thợ sau khi đã trả phí cá nhân: mặc định không thu thêm, loại được cố định khi phí đã trả (đã làm trong #203).
7. Khôi phục thợ đã bị thu hồi: mặc định cuối trong app; hỗ trợ xử lý ngoài, công cụ staff sau (#83).
8. Đổi số điện thoại sau khi được duyệt: mặc định vẫn đã duyệt, chỉ bước điện thoại hiện chưa xong tới khi xác minh lại.
9. Hộ kinh doanh: mã số thuế 12 số là số định danh cá nhân, hiện lưu dạng rõ ở `verifications/{uid}.business.taxCode`. Chỉ lưu băm hoặc 4 số cuối cho hộ kinh doanh? (mặc định hiện tại: lưu rõ, chờ chủ sản phẩm quyết).

## 12. Chia việc

1. Domain + Functions + rules: trạng thái, cổng `IdentityVerifier` (bản giả), chặn ở §7, staff duyệt. **Đã làm (#135).**
2. App: S21.01 đến S21.04, thay đổi S06.02, S03.01, S09.02 (dòng "Xác minh & nhận đơn" bật), thẻ "Còn {n} bước để nhận đơn". **Đã làm (#135).** S26.01 (giới hạn 3 thợ dẫn tới S21.04) là #136.
3. Phí xác minh: bước phí, `verification_fee` trên mô hình thanh toán chung, hai callable, `VerifyFeeScreen`, bật cờ ở server và app trong cùng một PR. **Đã làm (#203).**
4. Bản cài đặt thật (VNeID, chip CCCD, tra mã số thuế, vault KMS) sau khi có hợp đồng.
