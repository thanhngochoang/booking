# Spec — Loại nhà cung cấp, portfolio album, giải thưởng & hạng NAG, hợp đồng và Đăng việc

Ngày 2026-10-05. Bổ sung cho spec chính [`2026-10-01-remaining-screens.md`](2026-10-01-remaining-screens.md) (gọi là "spec chính"). Mock: `docs/design/ui-mock.html`, các mục "Loại nhà cung cấp", S03.01 (biến thể NAG), S08.01 (bước "Hình thức"), S10.01, S15, S16, S24, S25. Trên mock, khung chữ "Quy tắc đã chốt" và "Giả định" tóm tắt mục 1–5 dưới đây.

## 0. Phạm vi và cách chia

Bốn phần, mỗi phần một nhóm plan riêng:

| Phần | Nội dung | Use case |
|------|----------|----------|
| A | Loại nhà cung cấp (Photographer, NAG, Studio), dấu và nhãn, chọn Cá nhân/Studio khi thiết lập hồ sơ | thay đổi S01.05, S02.06, S03.01, S08.01, S08.05 |
| B | Giải thưởng và hạng Nhiếp ảnh gia (NAG) | S25, S23.07 |
| C | Portfolio dạng album (bản đầu chỉ ảnh, sau thêm video) | S24, thay đổi S03.01, S10.01, S09.01 |
| D | Đặt lịch theo kiểu hợp đồng freelancer (tiền 100% qua escrow theo mốc, bàn giao và duyệt) và Đăng việc | thay đổi S04, S05, S06; S15, S16 |

**Ngoài phạm vi**: Studio nhiều thành viên (một tài khoản studio quản lý nhiều thợ, phân người cho booking, chia tiền nội bộ). Phần A giữ chỗ cho nó (`providerType = studio`), thiết kế sau ở một spec riêng. Video trong album: chỉ chừa chỗ trong mô hình dữ liệu (mục 3.5).

**Đổi tên gọi**: trước ngày này các spec và bảng mã màn dùng "NAG" để chỉ **mọi** nhiếp ảnh gia (vai `photographer`). Từ nay **NAG chỉ là hạng nghệ sĩ** ở mục 2. Cột "Vai trò" trong bảng mã màn dùng "thợ ảnh" cho vai `photographer`; các spec cũ còn chữ "NAG" theo nghĩa cũ được hiểu là "thợ ảnh" cho tới khi sửa dần.

## 1. Loại nhà cung cấp (phần A)

### 1.1 Ba loại

| Loại | Mã `ProviderType` | Ai đặt | Dấu cạnh tên | Nhãn chữ |
|------|-------------------|--------|--------------|----------|
| Photographer (người chụp ảnh, cá nhân) | `individual` | Tự chọn ở S08.01 | Tích xanh tròn nếu đã xác minh (S21.02), không thì không có | Không có |
| Nhiếp ảnh gia (NAG, nghệ sĩ có tác phẩm đi thi hoặc đạt giải) | `artist` | **Chỉ server**, khi đủ điều kiện ở mục 2.3 | Tích vàng tròn (thay tích xanh) | "Nhiếp ảnh gia" (vàng), trên thẻ kèm "· n giải" |
| Studio (cơ sở kinh doanh chụp ảnh) | `studio` | Tự chọn ở S08.01 | Con dấu viền răng cưa tích vàng, chỉ khi đã xác minh giấy phép kinh doanh (S21.02 nhánh studio) | "Studio" (kèm quận trên thẻ) |

- NAG là **hạng nâng cấp của `individual`**. Studio không lên NAG. Một NAG sau này có thể là thành viên của một studio (spec Studio).
- Ba dấu khác nhau cả hình lẫn màu; nhãn chữ luôn đi kèm NAG và Studio để không chỉ dựa vào màu. `Semantics.label`: "Đã xác minh", "Nhiếp ảnh gia đã duyệt", "Studio đã xác minh".
- Vai `UserRole` không đổi (`customer`, `photographer`). `providerType` là thuộc tính của hồ sơ `Photographer`.

### 1.2 Chọn và đổi

- **S08.01 bước 1** thêm câu hỏi "Bạn nhận việc với tư cách": Cá nhân / Studio (`AppOptionTile`, chọn đơn, mặc định Cá nhân). Chọn Studio thì "Tên hiển thị" thành "Tên studio" và S08.05 thêm **địa chỉ cơ sở** (bắt buộc, công khai tới mức quận; địa chỉ đầy đủ chỉ lộ sau khi đã đặt, như số điện thoại).
- Đổi Cá nhân ↔ Studio ở Cài đặt (S09.02 → "Hình thức nhận việc") **chỉ khi không còn booking chưa xong, báo giá đang mở hay tiền đang giữ**. Đổi sang Studio thì mất hạng NAG (giải thưởng vẫn giữ); đổi lại Cá nhân thì hạng NAG được tính lại ở mục 2.3.
- Thợ ảnh cũ (trước khi có trường này) mặc định `individual`. Migration một lần.

### 1.3 Ảnh hưởng khác

- **S02.06, S02.02, S03.01, S15.03, S24.01**: dấu và nhãn theo bảng 1.1 qua `ProviderMark` và `ProviderTag` (mục 7).
- **Gợi ý** (`recommend`): `providerType` thành một đặc trưng lọc (lọc việc đăng "Chỉ Nhiếp ảnh gia / Chỉ Studio", mục 5). Chưa dùng để xếp hạng. Có cần chip lọc "Loại" ở S02.06 không: câu hỏi mở 1.
- **S03.01 biến thể NAG**: ô thống kê thứ hai "giải thưởng" thay "phản hồi"; hàng thẻ giải thưởng (đã duyệt, mới nhất trước) nằm chỗ hàng huy hiệu, huy hiệu dời xuống dưới bio. Studio: dòng meta có "Studio · quận".

## 2. Giải thưởng và hạng NAG (phần B)

### 2.1 Giải thưởng là danh sách trên hồ sơ

Giải không gắn vào từng bài (đã chốt). Mỗi giải: cuộc thi / triển lãm, năm, hạng mục (tuỳ chọn), kết quả, tác phẩm (tuỳ chọn, liên kết tới một bài của mình), minh chứng (ít nhất một: ảnh giấy chứng nhận hoặc link trang công bố kết quả).

`AwardResult`: `gold` (Vàng / Nhất), `silver` (Bạc / Nhì), `bronze` (Đồng / Ba), `honorable` (Khuyến khích), `finalist` (Top / Chung kết), `exhibited` (Được chọn triển lãm).

### 2.2 Duyệt từng giải

```
pending ──(staff duyệt)──▶ approved
   │ ──(cần bổ sung, có lý do)──▶ needs_info ──(chủ hồ sơ sửa)──▶ pending
   └ ──(từ chối, có lý do)──▶ rejected
approved ──(chủ hồ sơ sửa nội dung)──▶ pending      approved ──(staff thu hồi, có lý do)──▶ revoked
```

- Staff duyệt ở **S23.07** (nội bộ, chưa mock): xem minh chứng, Duyệt / Cần bổ sung / Từ chối, lý do bắt buộc trừ khi duyệt. Mục tiêu 3 ngày làm việc. Mọi quyết định ghi nhật ký kiểm toán (spec chính 3i.6).
- Minh chứng lưu riêng tư (chỉ chủ hồ sơ và staff đọc), xoá 30 ngày sau khi giải ra trạng thái cuối (`approved`, `rejected`, `revoked`). Chỉ giải `approved` hiện công khai.
- Studio vẫn khai giải được (hiện trên hồ sơ studio) nhưng không tính hạng.

### 2.3 Lên và mất hạng NAG

- Điều kiện (đề xuất, câu hỏi mở 2): `providerType = individual` và **≥ 3 giải `approved`**. Server tự đặt `providerType = artist` và `artistSince`, gửi thông báo `artist_granted`. Không có đơn xin riêng.
- Số giải đã duyệt tụt dưới ngưỡng (thu hồi, chủ hồ sơ xoá giải) → server đặt lại `individual`, gửi `artist_revoked`. Việc đăng "Chỉ Nhiếp ảnh gia" mà thợ ảnh đã báo giá trước đó vẫn giữ báo giá.
- Hạng NAG đã gồm kiểm tra danh tính của S21.02: khi cấp hạng mà thợ ảnh chưa có tích xanh, S23.07 yêu cầu staff xác minh danh tính cùng lúc. Vì vậy tích vàng thay tích xanh.

### 2.4 Màn

- **S25.01 Giải thưởng của tôi** (`/me/awards`): thẻ tiến độ "n / 3" (đã là NAG thì "Bạn là Nhiếp ảnh gia · từ …"), danh sách giải kèm trạng thái và lý do; nút chính "Thêm giải thưởng". Vào từ S09.02 và dòng nhắc ở S09.01 (hồ sơ Cá nhân).
- **S25.02 Thêm / sửa giải thưởng** (sheet). Nút "Gửi duyệt".
- Đặc tả từng màn: [`screens/portfolio-awards.md`](screens/portfolio-awards.md).

## 3. Portfolio album (phần C)

### 3.1 Khái niệm

- Mọi hồ sơ thợ ảnh (cả ba loại) có tab Portfolio với nút gạt **Album / Dòng thời gian**.
- **Dòng thời gian**: mọi bài `work` và `real_shoot` của thợ ảnh, mới nhất trước (masonry như S03.01 hiện tại).
- **Album**: thư mục do chủ hồ sơ tạo và sắp xếp. **Mỗi bài thuộc tối đa một album** (đã chốt). Bài chưa xếp album chỉ hiện ở Dòng thời gian.
- Mặc định của nút gạt: Album nếu có ≥ 1 album không trống, nếu không thì Dòng thời gian. Không có album nào không trống thì ẩn nút gạt.

### 3.2 Quy tắc

- Tên album 1–40 ký tự, không trùng tên album khác của cùng người (không phân biệt hoa thường). Mô tả ≤ 300 ký tự.
- Tối đa 30 album mỗi người, 200 bài mỗi album.
- Thứ tự album (`position`) và thứ tự bài trong album (`albumPosition`) do chủ hồ sơ đặt. Album đầu tiên hiện rộng hết hàng trên hồ sơ.
- Ảnh bìa: mặc định ảnh đầu của bài đầu tiên; chọn được một ảnh bất kỳ trong album. Bìa trỏ tới bài bị gỡ khỏi album hoặc bị xoá → quay về mặc định.
- Album trống không hiện công khai. Xoá album không xoá bài; bài về "Chưa xếp album".
- Bài bị xoá hoặc gỡ khỏi album thì các bài sau trong album dồn lên (không để lỗ hổng `albumPosition`).
- Kéo thả để sắp xếp luôn có cách không cần kéo: "…" → Chuyển lên / Chuyển xuống / Lên đầu / Xuống cuối (WCAG 2.2 "dragging movements").

### 3.3 Đăng bài (S10.01)

Công tắc "Thêm vào portfolio" bỏ, thay bằng ô **Album · tuỳ chọn** (mặc định album dùng gần nhất, chưa có album thì "Không xếp album") mở sheet S24.05. Bài mới thêm vào cuối album.

`Post.inPortfolio` thành giá trị dẫn xuất, luôn `true` với bài `work` (mọi bài đều ở Dòng thời gian), giữ lại để đọc ngược tương thích; ngừng ghi từ client. Minh chứng kỹ năng (S08.04) chọn từ mọi bài của mình.

### 3.4 Màn

S24.01 Chi tiết album (`/u/:uid/albums/:albumId`), S24.02 Album của tôi (`/me/albums`), S24.03 Tạo / sửa album (sheet), S24.04 Thêm bài vào album (sheet), S24.05 Chọn album khi đăng (sheet). Đặc tả: [`screens/portfolio-awards.md`](screens/portfolio-awards.md).

### 3.5 Video về sau

`PostImage` đổi tên thành `PostMedia { postId, position, kind: MediaKind, file, durationMs?, poster? }` với `MediaKind = image | video`. Bản đầu chỉ chấp nhận `image` (kiểm ở use case và rules). Album không phụ thuộc loại media. Firestore giữ trường `imageMeta[]` cũ và thêm `media[]` khi bật video (ánh xạ ở `relational-schema.md`).

## 4. Hợp đồng đặt lịch kiểu freelancer (phần D, nền)

### 4.1 Quyết định mặc định

Các quyết định dưới đây là đề xuất của buổi review 2026-10-05. Plan được viết theo chúng **trừ khi** câu hỏi mở 3–6 được trả lời khác.

1. **Toàn bộ tiền qua app.** Khách trả 100% giá khi đặt (gói, báo giá, Chụp ngay), không còn "70% trả tại buổi chụp". Tiền nằm trong escrow (spec chính 3g).
2. **Hai mốc thả tiền**, mặc định 50/50:
   - Mốc 1 `shoot`: thả khi buổi chụp `shot` (thợ ảnh bấm "Đã chụp xong", hoặc tự động `end + 24 giờ`) và hết cửa sổ khiếu nại của mốc 1 (24 giờ).
   - Mốc 2 `delivery`: thả khi khách **duyệt bàn giao**, hoặc **tự duyệt** sau 3 ngày kể từ `delivered` nếu khách không phản hồi.
3. **Bàn giao** là một bước trong app: thợ ảnh gửi link bộ ảnh (Google Drive, Dropbox, Pixieset… v1) kèm vài ảnh xem trước tải lên app (≤ 10, để làm bằng chứng khi khiếu nại). Lưu toàn bộ ảnh giao trên app: câu hỏi mở 5.
4. **Chỉnh sửa**: gói và báo giá có `revisions` (số lần sửa, 0–5). Khách "Yêu cầu chỉnh sửa" khi còn lượt → `revision_requested`, thợ ảnh nộp lại → `delivered`. Hết lượt thì chỉ còn Duyệt hoặc Khiếu nại.
5. **Trễ hạn**: quá `deliveryDays` sau `shot` mà chưa `delivered` → khách được "Huỷ phần bàn giao", hoàn 100% mốc 2; thợ ảnh giữ mốc 1.
6. **Khiếu nại** (S18) mở được trong cửa sổ của từng mốc; với mốc 2, cửa sổ là thời gian chờ duyệt.
7. **Chưa thu hoa hồng** ở v1 (sổ cái đã có `fee_charged`). Câu hỏi mở 6.

### 4.2 Booking thành hợp đồng chung

`Booking` thêm:
- `source: BookingSource` (`package`, `quote`, `instant`). `serviceId` chỉ bắt buộc khi `source = package`.
- `terms: BookingTerms` (bản chụp lúc tạo): `price: Money`, `durationMinutes`, `photoCount`, `editedCount`, `deliveryDays`, `revisions`, `milestones: List<{kind: MilestoneKind, percent}>`. Thay `serviceSnapshot` (giữ để đọc ngược).
- `jobId?`, `quoteId?` khi `source = quote`.
- `revisionsUsed`, `shotAt?`, `deliveredAt?`, `approvedAt?`, `autoApproveAt?`.
- Bỏ `deposit` / `remaining`. Bất biến cũ "cọc + còn lại = giá" thay bằng "Σ `Milestone.amount` = `terms.price`".

`Milestone`: `bookingId`, `kind: MilestoneKind` (`shoot`, `delivery`), `amount: Money`, `status: MilestoneStatus` (`held`, `released`, `refunded`, `disputed`), `releaseAfter?`, `releasedAt?`. Một `Payment` cho cả booking; mỗi mốc ứng với các bút toán `escrow_released` riêng trên `Payment` đó (ledger không đổi loại bút toán).

`Delivery`: `id`, `bookingId`, `round` (1 + số lần sửa), `link`, `previews: List<FileRef>` (≤ 10), `note?`, `submittedAt`, `decision?: {kind: approve | request_revision, note?, at}`.

### 4.3 Máy trạng thái mới

```
draft ──(paid)──▶ requested ──(thợ nhận)──▶ accepted           (source = package)
draft ──(paid)──▶ accepted                                       (source = quote: thợ đã đồng ý khi báo giá)
accepted ──(T‑24h)──▶ upcoming ──(thợ "Đã chụp xong" | end+24h)──▶ shot
shot ──(thợ nộp bàn giao)──▶ delivered ──(khách duyệt | hết 3 ngày)──▶ completed ──(đánh giá)──▶ reviewed
delivered ──(khách yêu cầu sửa, còn lượt)──▶ revision_requested ──(thợ nộp lại)──▶ delivered
shot ──(quá deliveryDays, khách huỷ phần giao)──▶ completed (mốc 2 hoàn 100%)
requested ──decline / quá hạn nhận──▶ declined / expired (hoàn 100%)
requested/accepted/upcoming ──khách huỷ──▶ cancelled (hoàn theo chính sách, tính trên 100%)
accepted/upcoming ──thợ huỷ──▶ cancelled (hoàn 100%)
```

- `BookingStatus` thêm `shot`, `delivered`, `revision_requested`. `completed` giờ nghĩa là "đã duyệt bàn giao" (trước là "đã chụp xong").
- Chính sách huỷ trước buổi chụp giữ tỉ lệ cũ (≥ 48 giờ 100%, 24–48 giờ 50%, < 24 giờ 0%) nhưng tính trên toàn bộ tiền đã trả; phần giữ lại chia theo mốc 1 trước.
- Chụp ngay (S13–S14) đã trả đủ trước: chỉ thêm `shot → delivered → completed` sau `in_progress` (spec Chụp ngay cập nhật trong plan riêng).

### 4.4 Ảnh hưởng tới phần đã làm (cần plan sửa)

| Đã làm | Sửa |
|--------|-----|
| 4a booking backend (`transition_booking`, `createDeposit`) | Trạng thái mới, `createPayment` thay `createDeposit` (trả đủ), mốc, auto‑approve cron |
| 4b sheet đặt lịch | S04.03: bảng tiền "Thanh toán 100% · giữ trên app, chuyển theo 2 mốc", bỏ "còn lại trả tại buổi chụp"; nút "Thanh toán {giá}" |
| 4c chi tiết booking, danh sách | S05.02: `StatusTimeline` thêm Đã chụp · Đã giao ảnh · Đã duyệt; khối bàn giao (link, ảnh xem trước, Duyệt / Yêu cầu chỉnh sửa); thợ ảnh: "Đã chụp xong", "Nộp bàn giao" |
| 4e đánh giá | Mở khi `completed` mới (sau duyệt), không còn ngay sau buổi chụp |
| S06.05 thu nhập | Từng khoản hiện theo mốc: Đang giữ · Chờ duyệt · Chờ chi trả · Đã chuyển |
| Chính sách hiển thị (`EscrowNotice`, `PolicyTable`) | Chữ mới theo 100% và mốc |

Màn mới của phần này (chưa mock, đặt mã khi viết plan, trong S05/S06): "Nộp bàn giao" (thợ ảnh, sheet), "Xem bàn giao" (khách). Theo quy tắc mã màn, lấy `.yy` kế tiếp: S05.06 Xem bàn giao & duyệt, S05.07 Yêu cầu chỉnh sửa (sheet), S06.07 Nộp bàn giao (sheet). **Chưa** thêm vào bảng mã cho tới khi có mock.

## 5. Đăng việc (phần D, S15–S16)

### 5.1 Luồng

1. Khách đăng việc (S15.01, 2 bước). Cần số điện thoại (S04.05 trước bước 1).
2. Server gợi ý việc cho thợ ảnh phù hợp (`job_match`, tối đa 30 người mỗi việc) và gửi lời mời cho người khách chọn (`job_invited`, tối đa 5).
3. Thợ ảnh xem (S16.01) và gửi báo giá (S16.03). Khách nhận `quote_new` (gộp theo việc).
4. Khách so sánh (S15.03), xem chi tiết (S15.04), "Chọn và thanh toán" → bước xem lại của S04.03 → trả 100%.
5. Trả xong: tạo `Booking { source: quote, status: accepted }` theo `terms` của báo giá; việc `awarded`; báo giá được chọn `accepted`; báo giá khác `not_selected` (thông báo cho từng người).

### 5.2 Trạng thái

```
JobPost: draft ─▶ open ─(khách chọn và trả)─▶ awarded
              open ─(hết hạn nhận báo giá)─▶ expired      open ─(khách đóng)─▶ closed
Quote:   submitted ─(sửa)─▶ submitted   submitted ─(rút)─▶ withdrawn
         submitted ─(được chọn và trả)─▶ accepted       submitted ─(việc awarded/expired/closed)─▶ not_selected
         submitted ─(khách từ chối)─▶ declined          submitted ─(thợ nhận booking khác trùng ngày)─▶ withdrawn (tự động)
```

- `expired` / `closed`: "Đăng lại" tạo nháp mới từ việc cũ, không mở lại việc cũ.
- Hạn nhận báo giá 1–7 ngày (mặc định 3), gia hạn tối đa một lần thêm 7 ngày. Ngày chụp phải sau hạn nhận báo giá.
- Khách sửa nội dung việc chỉ khi chưa có báo giá; có rồi thì chỉ gia hạn hoặc đóng.

### 5.3 Quy tắc

- **Ai thấy việc**: thợ ảnh đã hoàn tất hồ sơ, việc nằm trong khu vực phục vụ (`serviceArea` chứa quận của việc) và đúng `allowedProviders` (`all`, `artist`, `studio`). Việc "Chỉ Nhiếp ảnh gia" vẫn hiện mờ với `individual` kèm lối lên NAG (S25.01), không gửi được báo giá.
- **Thông tin riêng tư**: việc chỉ lộ quận và khoảng ngày giờ; địa chỉ cụ thể nhập ở bước thanh toán (S04.03), chỉ người được chọn thấy. Người đăng chỉ hiện tên, avatar, số lần đã thuê, cờ SĐT đã xác minh. Không bao giờ có số điện thoại trong việc, báo giá hay lời nhắn: server lọc số điện thoại, email, link ngoài trong tiêu đề, mô tả, lời nhắn (trả `invalid_argument` kèm trường).
- **Một báo giá cho mỗi (việc, thợ ảnh)**; sửa và rút được khi việc còn `open` và báo giá chưa được chọn. Không xem được giá của người khác; chỉ thấy số báo giá.
- **Báo giá không giữ chỗ trên lịch.** Ngày đã có booking hoặc ngày nghỉ thì không gửi được (`day_taken`). Thợ ảnh nhận booking khác trùng ngày thì báo giá tự rút và khách được báo.
- **Giá** > 0, số nguyên VND; mốc tự tính theo tỉ lệ mặc định (mục 4.1). Lời nhắn 20–500 ký tự. Có thể "Dựa trên gói" để điền sẵn giá và bàn giao.
- **Giới hạn chống spam** (đề xuất): khách tối đa 3 việc `open` cùng lúc; thợ ảnh tối đa 20 báo giá `submitted` cùng lúc.
- **Chat**: S15.04 và S16.01 mở chat hỏi trước (`Chat.kind = inquiry`) gắn `jobId`; giới hạn 3 tin khi bên kia chưa trả lời giữ nguyên. Sau khi thanh toán chat thành `booking` như luồng hiện tại và các kênh gọi, Zalo, WhatsApp mở theo quy tắc cũ.
- **Độ phù hợp** ("Hợp 92%"): từ `RecommendationRepository` (thể loại, kỹ năng, khoảng cách, lịch rảnh, ngân sách so với giá gói, loại nhà cung cấp). Là gợi ý, không phải điều kiện.

### 5.4 Điểm vào trong app

- Khách: tab Đặt lịch (S05.01) thêm `SegmentedTabs` **Buổi chụp / Vé sự kiện / Việc đăng** (thay hai tab của S11.04); S02.06 khi không có kết quả ("Không tìm thấy? Đăng việc để thợ ảnh báo giá"); S03.01 menu "…" → "Mời báo giá" cho một việc đang mở.
- Thợ ảnh: tab Công việc (S06.01) thêm `SegmentedTabs` **Hôm nay / Việc tuyển / Báo giá**.

### 5.5 Thông báo

Dùng các loại đã có ở spec chính 3h.2 (`quote_new` gộp theo `job:<id>:quotes`, `job_match`, `job_invited`) và thêm: `quote_accepted` (thợ ảnh, → S05.02), `quote_not_selected` (thợ ảnh, → S16.01), `quote_withdrawn` (khách, → S15.03), `job_expiring` (khách, 24 giờ trước hạn khi có ≥ 1 báo giá, → S15.03), `job_expired` (khách, → S15.02). Kênh `jobs` trong cài đặt thông báo đã có.

### 5.6 Màn

S15.01–S15.04, S16.01–S16.03 theo mock. Đặc tả: [`screens/jobs.md`](screens/jobs.md).

## 6. Dữ liệu và server

### 6.1 Thực thể mới (chi tiết ở `data-model/domain-model.md`)

| Thực thể | Trường chính |
|----------|--------------|
| `Photographer` (thêm) | `providerType: ProviderType = individual`, `artistSince?`, `approvedAwardCount` (dẫn xuất), `studioAddress?` 🔒 |
| `Award` | `id`, `photographerId`, `competition`, `year`, `category?`, `result: AwardResult`, `workPostId?`, `status: AwardStatus`, `reviewNote?`, `reviewedBy?`, `reviewedAt?`, `createdAt`, `updatedAt` |
| `AwardProof` 🔒 | `awardId`, `files: List<FileRef>`, `links: List<Url>`, `purgeAfter?` |
| `Album` | `id`, `photographerId`, `title`, `description?`, `cover?: {postId, position}`, `position`, `postCount`, `mediaCount` (dẫn xuất), `createdAt`, `updatedAt` |
| `Post` (thêm) | `albumId?`, `albumPosition?` |
| `Service` (thêm) | `revisions = 1` |
| `Booking` (đổi) | mục 4.2 |
| `Milestone`, `Delivery` | mục 4.2 |
| `JobPost` | `id`, `customerId`, `specialtyId`, `title`, `description`, `references: List<FileRef>` (≤ 5), `schedule: {kind: fixed | flexible, day?, start?, end?, from?, to?, durationMinutes}`, `area: {city, district, geohash}`, `budget?: {min: Money, max: Money}`, `wants: {editedCount?, deliveryDays?}`, `allowedProviders: AllowedProviders`, `quoteDeadline: Instant`, `extended = false`, `status: JobStatus`, `quoteCount`, `viewCount`, `awardedQuoteId?`, `bookingId?`, `createdAt`, `updatedAt` |
| `Quote` | `id`, `jobId`, `photographerId`, `basedOnServiceId?`, `terms: BookingTerms`, `message`, `albumId?`, `status: QuoteStatus`, `createdAt`, `updatedAt` |
| `JobInvite` | `jobId`, `photographerId`, `createdAt`, `seenAt?` |

Enum mới: `ProviderType`, `AwardResult`, `AwardStatus` (`pending`, `needs_info`, `approved`, `rejected`, `revoked`), `BookingSource`, `MilestoneKind`, `MilestoneStatus`, `JobStatus` (`draft`, `open`, `awarded`, `expired`, `closed`), `QuoteStatus` (`submitted`, `withdrawn`, `accepted`, `not_selected`, `declined`), `AllowedProviders` (`all`, `artist`, `studio`), `MediaKind`. `BookingStatus` thêm `shot`, `delivered`, `revision_requested`. `ErrorCode` thêm `not_eligible` (đã có) cho báo giá sai loại, `limit_exceeded` (đã có) cho giới hạn.

### 6.2 Firestore

`awards/{id}`, `awardProofs/{id}` (rules: chỉ chủ và staff), `albums/{id}`, `posts/{id}.albumId/albumPosition`, `bookings/{id}/milestones/{kind}`, `bookings/{id}/deliveries/{round}`, `jobs/{id}`, `jobs/{id}/quotes/{photographerId}` (id = uid nên một báo giá mỗi người là bất biến của đường dẫn), `jobs/{id}/invites/{photographerId}`. Rules: thợ ảnh đọc `jobs` đang `open`; khách đọc mọi báo giá của việc mình; thợ ảnh chỉ đọc báo giá của mình; `providerType = artist`, `Award.status`, `Album.postCount`, `Job.quoteCount`, `Milestone.*` chỉ server ghi.

### 6.3 Cloud Functions (callable, `asia-southeast1`; quy tắc trong `packages/domain`)

`createAward`, `updateAward`, `deleteAward`, `reviewAward` (staff) + trigger tính lại hạng; `createAlbum`, `updateAlbum`, `deleteAlbum`, `reorderAlbums`, `movePostsToAlbum`, `reorderAlbumPosts`; `createJob`, `extendJob`, `closeJob`, `inviteToJob`, `submitQuote`, `withdrawQuote`, `declineQuote`, `acceptQuote` (tạo booking `draft` + payment), cron `expireJobs`; `markShot`, `submitDelivery`, `approveDelivery`, `requestRevision`, `cancelLateDelivery`, cron `autoApproveDeliveries`, `releaseMilestones`.

## 7. Thành phần dùng chung mới

`ProviderMark` (thay vai trò của `VerifiedMark`: `kind: verified | artist | studio`), `ProviderTag`, `AwardChip` (thẻ giải trên hồ sơ), `AwardRow` (S25.01), `PortfolioViewToggle` (Album / Dòng thời gian), `AlbumTile`, `ReorderableRow` (tay nắm + menu chuyển lên/xuống), `PostPickerGrid` (chọn nhiều, số thứ tự), `JobCard` (hai biến thể khách / thợ ảnh), `QuoteCard`, `DeliverableChips`, `MilestoneTable`, `FitPill` ("Hợp n%"). Đặc tả ở `components/shared-components.md`.

## 8. Thông báo: bỏ chuông ở đầu trang (quyết định 2026-10-05)

Người dùng quyết định không có biểu tượng chuông ở góc trên phải. Số thông báo chưa đọc (`users/{uid}/private/inbox.unreadCount`) hiện bằng `TabBadge` trên **tab Hồ sơ**; S09.01 có dòng "Thông báo" ngay dưới tên (số chưa đọc + thông báo mới nhất) mở S17.01. `NotificationBell` gỡ khỏi S02.01, S02.03, S02.04, S06.01 (và không dùng ở S16.02). Biểu tượng chat ở S02.01 giữ nguyên. Khi tab Hồ sơ đã có số thông báo, các tab khác vẫn giữ chấm số riêng của chúng (spec chính 3d.3).

## 9. Thứ tự triển khai (đề xuất cho RUN-ORDER)

1. **A1** loại nhà cung cấp: trường, migration, `ProviderMark`/`ProviderTag`, S08.01, S03.01 dấu/nhãn, S02.06.
2. **C1** album backend + S10.01 + S24.05; **C2** S03.01 tab Portfolio + S24.01; **C3** S24.02–S24.04.
3. **B1** giải thưởng backend + S25.01–S25.02 + S03.01 hàng giải; **B2** S23.07 (sau khi chốt công cụ nội bộ, câu hỏi mở 22 của spec chính).
4. **D1** hợp đồng (booking 100%, mốc, bàn giao, duyệt) sửa 4a–4c, 4e; **D2** màn bàn giao (S05.06, S05.07, S06.07, cần mock trước).
5. **D3** Đăng việc backend; **D4** S15; **D5** S16.
6. **N1** thông báo: tab Hồ sơ + dòng ở S09.01, gỡ `NotificationBell` (nhỏ, làm cùng plan thông báo S17).

A1 trước B1 (B cần `providerType`). D1 trước D3 (báo giá tạo booking theo hợp đồng mới). C độc lập, chạy song song với D.

## 10. Kiểm thử

- `packages/domain`: điều kiện lên/mất hạng NAG; chuyển trạng thái `Award`, `JobPost`, `Quote`, `Booking` mới (bảng chuyển hợp lệ, chuyển sai trả lỗi); Σ mốc = giá; chia tiền khi huỷ trước buổi chụp; trễ hạn bàn giao; tự duyệt; lọc số điện thoại / link; giới hạn số việc và báo giá; một báo giá mỗi (việc, thợ).
- Rules test: thợ ảnh không đọc được báo giá của người khác; không ai ngoài server ghi `providerType = artist`; minh chứng giải chỉ chủ và staff đọc; album trống không đọc công khai được (lọc phía truy vấn).
- Widget test theo từng màn (mẫu ở `screens/README.md`); test kéo thả có đường thay thế không cần kéo.
- `screen_codes_test.dart` qua với bảng mã mới (S23.07, S24.01–S24.05, S25.01–S25.02).

## 11. Câu hỏi mở

1. Có chip lọc "Loại" (Photographer / Nhiếp ảnh gia / Studio) ở S02.06 không?
2. Ngưỡng NAG: 3 giải đã duyệt có hợp lý? Có tính trọng số theo kết quả (Vàng > Khuyến khích) hay theo cấp cuộc thi (quốc tế, quốc gia, địa phương)?
3. 100% qua app (đề xuất) hay giữ cọc 30% + 70% ngoài app? Nếu 100%, câu hỏi mở 19 của spec chính (pháp lý giữ tiền hộ) phải chốt trước khi bật cổng thật.
4. Tỉ lệ hai mốc (50/50 đề xuất) cố định hay thợ ảnh chọn trong khoảng (ví dụ 30–70%)? Số ngày tự duyệt (3 đề xuất)?
5. Bàn giao: link ngoài + ảnh xem trước (đề xuất) hay lưu toàn bộ ảnh giao trên Storage (chi phí, thời hạn lưu)?
6. Hoa hồng nền tảng: có thu không, tỉ lệ, ai chịu (khách, thợ ảnh, chia đôi)?
7. Giới hạn chống spam (3 việc mở / khách, 20 báo giá mở / thợ ảnh) có cần thu phí báo giá kiểu "connects" như các nền tảng freelancer không?
8. Studio nhiều thành viên: spec riêng; trong lúc chờ, Studio là một tài khoản như cá nhân.
