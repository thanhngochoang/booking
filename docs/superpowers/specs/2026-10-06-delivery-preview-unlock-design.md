# Bàn giao hai lớp: ảnh mẫu có watermark, link ảnh gốc mở khi khách đồng ý

Ngày: 2026-10-06 · Trạng thái: đã làm (#152) · Sửa: `2026-10-05-provider-types-portfolio-jobs-design.md` §4.1 mục 3–4 và §4.3 (máy trạng thái). Áp dụng cho **mọi booking** (gói, báo giá, Chụp ngay; cá nhân và studio).

## 1. Vì sao

Spec 2026-10-05 cho thợ gửi link bộ ảnh ngay khi bàn giao, kèm vài ảnh xem trước. Khi đó thợ lộ toàn bộ ảnh gốc trước khi khách đồng ý, còn khách cũng không có chỗ để trao đổi rõ ràng về màu và chỉnh sửa. Bàn giao hai lớp tách việc **duyệt chất ảnh** (trên ảnh mẫu có watermark) khỏi việc **nhận ảnh gốc** (link mở sau khi khách đồng ý).

Không đổi: khách trả 100% khi đặt, tiền giữ trên app, chuyển theo hai mốc 50/50 (quyết định 2026-10-06, ghi ở `docs/legal/terms-and-help-notes.md` P9).

## 2. Quyết định đã chốt

| # | Quyết định |
|---|---|
| B1 | Một lần bàn giao gồm **ảnh mẫu (3–20)** có watermark do server đóng và **link bộ ảnh gốc** bị che. |
| B2 | Khách đồng ý trên ảnh mẫu thì link mở. Hai bên trao đổi chỉnh màu, sửa, photoshop qua các vòng ảnh mẫu. |
| B3 | Số vòng sửa miễn phí theo gói/báo giá (`terms.revisions`, 0–5). Hết lượt: khách đồng ý, xin thêm vòng (người bàn giao cho hoặc không), hoặc mở khiếu nại. |
| B4 | Link mở ngay khi khách đồng ý (hoặc tự đồng ý sau 3 ngày im lặng). Khách có **48 giờ kiểm tra** bộ ảnh gốc; không báo vấn đề thì mốc 2 chuyển. |
| B5 | Người bàn giao: thợ (booking cá nhân), **studio** (booking studio, spec `2026-10-06-studio-members-design.md`). |
| B6 | Màn đánh giá mở ngay khi link mở (`approved`). |
| B7 | Watermark do **server** đóng: thợ tải bản sạch lên vùng tạm chỉ thợ ghi được (`deliveryUploads/{bookingId}/{uid}/{fileId}.jpg`), Function đóng watermark vào `deliveries/{bookingId}/` rồi **xoá bản sạch ngay**. |
| B8 | **Không bao giờ** đóng watermark trên máy khách; bản sạch không tới máy khách. |
| B9 | Ảnh mẫu nén cạnh dài 1600 px, JPEG q75, bỏ EXIF; thêm ảnh thu nhỏ 400 px cho lưới. |
| B10 | Storage rules: chỉ JPEG, ≤ 2 MiB mỗi ảnh tải lên (`jpegUpTo(2 * 1024 * 1024)`, mục đích ảnh `deliverySample` của #147); chỉ hai bên booking đọc `deliveries/`. |

## 3. Dữ liệu

`Delivery` (thay định nghĩa ở spec 2026-10-05 §4.2), mỗi vòng một bản ghi `bookings/{id}/deliveries/{round}`:

| Trường | Ghi chú |
|---|---|
| `round` | 1, 2, … |
| `samples` | 3–20 `{fileId, path, thumbPath, width, height}` **đã đóng watermark** (khách đọc được) |
| `photoCount` | số ảnh trong bộ gốc (người bàn giao khai) |
| `linkHost` | host của link bộ ảnh gốc (ví dụ `drive.google.com`) để vẽ `drive.google.com/••••` mà không lộ URL đầy đủ |
| `note?` | ghi chú của người bàn giao |
| `submittedAt`, `submittedBy` | `submittedBy` là thợ hoặc chủ studio |
| `decision?` | `{kind: approve \| request_revision, note?, photoNotes: [{sampleIndex, note}], at, auto: bool, extra: bool}` |

Link bộ ảnh gốc nằm ở `bookings/{id}/private/delivery` (`link`, `round`, `unlockedAt`). Rules: người bàn giao đọc/ghi qua callable; khách **không đọc** cho tới khi `booking.status ∈ {approved, completed}`. Server ghi trường `unlockedAt` khi mở.

Tiến trình tải và đóng watermark lưu tạm tại `bookings/{id}/deliverySamples/{fileId}` (`uploaderId`, `status: ready|failed`, `path`, `thumbPath`, `width`, `height`, `bytes`, `failure?`, `createdAt`). Chỉ thợ đọc.

`Booking` thêm:
- `shotAt`, `deliveredAt`, `approvedAt`, `checkUntil` (= `approvedAt` + 48 giờ), `autoApproveAt` (= `deliveredAt` + 72 giờ), `autoApproveNoticeAt`.
- `deliveryRound` (vòng hiện tại, 0 khi chưa có vòng nào).
- `revisionsIncluded` (số vòng sửa miễn phí, 0–5, mặc định 1).
- `revisionsUsed` (số vòng đã sửa).
- `revisionsGranted` (số vòng người bàn giao cho thêm).
- `extraRound` (`{status: pending|granted|declined, at, note, photoNotes}` hoặc null).
- `samplesPurgeAfter` (thời điểm xoá ảnh mẫu, 90 ngày sau `completed`), `samplesPurged` (bool).

Hai mốc tiền: `payments/{id}` thêm `milestones: [{kind: shoot|delivery, amount, status, releaseAfter, releasedAt, payoutId}]`, `payableAmount`. Read model: `bookings/{id}/milestones/{kind}`.

**Watermark**: Cloud Function Storage trigger `onDeliveryUpload` chạy khi ảnh mẫu tải lên `deliveryUploads/{bookingId}/{uid}/{fileId}.jpg`: thu cạnh dài về tối đa 1600 px (JPEG q75, bỏ EXIF), dùng `opentype.js` và `sharp` đóng chữ "{tên người bàn giao} · Bản xem trước" lặp chéo toàn ảnh (nghiêng −32°, mờ 35%), sinh ảnh thu nhỏ 400 px `_t.jpg`, ghi `bookings/{id}/deliverySamples/{fileId}` trạng thái `ready` và **xoá ngay tệp sạch trong vùng tải lên**. Ảnh mẫu đã đóng watermark tự động xoá sau 90 ngày kể từ khi booking hoàn thành.

## 4. Máy trạng thái (thay §4.3 của spec 2026-10-05)

```
upcoming ──(thợ quét mã của khách, S30)──▶ shooting ──(thợ "Đã chụp xong" | quá kết thúc + 24 giờ)──▶ shot
upcoming ──(kết thúc + 24 giờ, không ai quét: hỏi khách "Buổi chụp có diễn ra không?")──▶ shot (khách trả lời "Có" hoặc im lặng 48 giờ)
shot ──(nộp bàn giao)──▶ delivered
delivered ──(khách yêu cầu sửa, còn lượt)──▶ revision_requested ──(nộp vòng mới)──▶ delivered
delivered ──(khách đồng ý | im lặng 3 ngày)──▶ approved          link mở, checkUntil = +48 giờ
approved ──(48 giờ không báo vấn đề)──▶ completed                  mốc 2 chuyển
approved ──(khách "Báo vấn đề với ảnh gốc")──▶ disputed (S18)     mốc 2 tiếp tục giữ
delivered ──(hết lượt, một bên mở khiếu nại)──▶ disputed (S18)
shot ──(quá deliveryDays, khách huỷ phần giao)──▶ completed (mốc 2 hoàn 100%)
```

- `BookingStatus` thêm `approved`. `completed` nghĩa là "đã đồng ý ảnh và hết 48 giờ kiểm tra" (hoặc huỷ phần giao).
- Hết lượt sửa: `delivered` vẫn chờ khách; khách chọn đồng ý, "Xin thêm 1 vòng" (người bàn giao bấm "Cho thêm 1 vòng" → `revisionsGranted + 1`, `revisionsUsed + 1` và `revision_requested`, hoặc "Không thêm" → `declined`), hoặc khiếu nại. Người bàn giao cũng mở được khiếu nại nếu khách liên tục từ chối mà không còn lượt.
- Đồng hồ tự đồng ý 3 ngày đặt lại mỗi khi có vòng ảnh mẫu mới.
- Một job định kỳ `bookingClock` (mỗi 15 phút) xử lý `autoApproveAt`, nhắc trước 24 giờ (`autoApproveNoticeAt`), `checkUntil` (chuyển sang `completed` và giải ngân mốc 2 nếu không khiếu nại), và dọn dẹp ảnh mẫu sau 90 ngày (`samplesPurgeAfter`).
- `mark_shot` thay thế `complete` để chuyển `upcoming → shot` sau khi buổi chụp kết thúc. Từ #223 (S30), booking có mã gặp thợ phải qua `shooting` (thợ quét mã) trước khi thợ bấm "Đã chụp xong"; booking không có mã (Chụp ngay, thanh toán trước khi S30 ra mắt) vẫn bấm được sau khi kết thúc.
- Việc tự chuyển `shot` lúc kết thúc + 24 giờ chỉ còn cho booking đã `shooting`. Booking vẫn `upcoming` lúc đó được hỏi khách "Buổi chụp có diễn ra không?" thay cho `shot` tự động: "Có" hoặc im lặng 48 giờ thì `shot` (`shotAt` = giờ kết thúc); "Không" ghi `shootDeniedAt`, tiền vẫn giữ, app mở khiếu nại S18 với lý do "Buổi chụp không diễn ra" (hệ thống tự mở sau 48 giờ nếu khách không mở). Chi tiết ở spec `2026-10-12-spot-organizer-entry-tickets-design.md` §6.3.

### Quyết định của chủ dự án 2026-10-18

| # | Quyết định | Ghi chú |
|---|---|---|
| D1 | Khách xin thêm vòng mà người bàn giao chưa trả lời: **đồng hồ tự duyệt 72 giờ vẫn chạy**, không tạm dừng. Thợ im lặng thì ảnh được duyệt, khách còn 48 giờ kiểm tra và khiếu nại. | Trả lời "Needs the owner 2" của kế hoạch #152; test ghim ở #207. |
| D2 | Booking đã `completed` với thanh toán hai mốc thì **không mở khiếu nại được nữa** (mốc 2 đã chuyển): cửa sổ 48 giờ kiểm tra là cơ hội cuối. Cửa sổ 24 giờ sau `completed` chỉ còn cho thanh toán cũ một khoản. | Làm ở #207 (`openDispute` từ chối rõ ràng). |
| D3 | **Huỷ phần bàn giao khi trễ hạn** (spec 10-05 §4.1.5): chỉ khi `shot` và `now > shotAt + deliveryDays × 24 giờ`; `deliveryDays` chụp từ gói lúc đặt (`deliverables.deliveryDays`, mặc định **7**, 1–90); hoàn đúng số tiền mốc 2, mốc 1 giữ nguyên trạng thái; booking → `completed` kèm `deliveryCancel`. Màn S05.08 và biến thể `#S05.02-late`. | Kế hoạch `2026-10-18-s05-late-delivery-cancel.md` (#207). |

## 5. Màn hình

Mã đã giữ chỗ trong spec 2026-10-05, nay vào bảng mã vì đã có mock:

| Mã | Màn | Ai |
|---|---|---|
| S05.06 | Xem bàn giao & duyệt | khách |
| S05.07 | Yêu cầu chỉnh sửa (sheet) | khách |
| S06.07 | Nộp bàn giao (sheet) | thợ, hoặc chủ studio với booking studio |

**S05.06** (`/b/:id/delivery`): tiêu đề "Bàn giao · vòng {n}"; dòng "{người bàn giao} gửi {k} ảnh mẫu · {ngày}"; lưới ảnh mẫu (chạm mở toàn màn, vẫn có watermark); thẻ "Bộ ảnh gốc · {photoCount} ảnh" với biểu tượng khoá, link che dạng `drive.google.com/••••` và dòng "Mở khi bạn đồng ý ảnh"; "Còn {x}/{y} lượt sửa miễn phí"; "Tự đồng ý sau {thời gian} nếu bạn không phản hồi"; thanh dưới: viền "Yêu cầu chỉnh sửa" + chính "Đồng ý ảnh" (sheet xác nhận ngắn: "Đồng ý thì link ảnh gốc mở ra; bạn có 48 giờ để kiểm tra").

**S05.06 sau khi đồng ý**: thẻ link đã mở và nút viền "Mở bộ ảnh gốc" (mở trình duyệt ngoài); "Kiểm tra bộ ảnh gốc trong 48 giờ: còn {h} giờ" kèm thanh thời gian; nút chữ đỏ "Báo vấn đề với ảnh gốc" (→ S18.01 với lý do điền sẵn: thiếu ảnh, khác ảnh mẫu, link hỏng); nút chính "Đánh giá buổi chụp" (→ S05.05).

**S05.07** (sheet): chọn ảnh mẫu và ghi chú từng ảnh (chip gợi ý: "Da sáng hơn", "Bớt vàng", "Xoá vật thể", "Cân lại nghiêng"); "Ghi chú chung"; "Vòng sửa {n}/{tổng} (miễn phí)"; nút chính "Gửi yêu cầu". Hết lượt thì sheet thành "Xin thêm 1 vòng".

**S06.07** (sheet): "Nộp bàn giao · vòng {n}"; lưới tải ảnh mẫu (3–20, "server tự đóng watermark sau khi tải lên", ô ảnh có bốn trạng thái: đang tải, đang đóng watermark, xong, lỗi · thử lại); ô "Link bộ ảnh gốc" (kiểm tra là URL http(s)); "Số ảnh gốc"; "Ghi chú" (tuỳ chọn); dòng "Khách chỉ thấy link sau khi đồng ý ảnh mẫu"; nút chính "Nộp bàn giao". Vòng ≥ 2 hiện ghi chú sửa của khách ở đầu sheet. Với booking studio, thợ được giao không thấy lối vào màn này.

**Chuỗi** (`app_vi.arb`, tiền tố `delivery*`): theo các câu trên; khoá cụ thể đặt trong plan.

## 6. Thông báo (S17)

| Loại | Gửi cho | Nội dung |
|---|---|---|
| `delivery_submitted` | khách | "{tên} đã gửi ảnh mẫu, xem và đồng ý để nhận ảnh gốc" |
| `delivery_revision_requested` | người bàn giao | "Khách muốn chỉnh sửa vòng {n}" |
| `delivery_approved` | người bàn giao | "Khách đã đồng ý ảnh; tiền chuyển sau 48 giờ kiểm tra" |
| `delivery_auto_approve_soon` | khách | 24 giờ trước khi tự đồng ý |
| `delivery_extra_round` | khách | người bàn giao cho thêm hoặc không cho thêm vòng |

Hook: `notifyDeliverySubmitted`, `notifyDeliveryRevisionRequested`, `notifyDeliveryApproved`, `notifyDeliveryAutoApproveSoon`, `notifyDeliveryExtraRound` trong `packages/domain/src/notification_hooks.ts` (#138); chỉ plan bàn giao (#152) gọi, từ trigger `onBookingWrite` và bước `remindAutoApprovals` của `bookingClock` (một lần mỗi vòng).

## 7. Giới hạn

- App chỉ che link **trong app**. Người bàn giao tự gửi link qua chat hay kênh khác trước khi khách đồng ý là lựa chọn của họ; điều khoản ghi rõ điều này.
- Không lưu bộ ảnh gốc trên app (câu hỏi mở 5 của spec 2026-10-05 giữ nguyên).
- Ảnh mẫu bản sạch không bao giờ gửi tới thiết bị khách; bản sạch xoá ngay sau khi đóng watermark trên server.
- Ảnh mẫu có watermark tự xoá sau 90 ngày kể từ khi booking hoàn thành.

## 8. Ảnh hưởng tới tài liệu và phần đã làm

- Spec 2026-10-05 §4.1 mục 3–4, §4.3: thêm ghi chú "Đổi 2026-10-06" trỏ về spec này.
- Spec cà chua/gạch: đánh giá mở ở `approved` thay vì `completed`.
- `docs/legal/terms-and-help-notes.md`: P2–P4 viết lại theo hai lớp.
- Code: chưa làm bàn giao (4a/4c chỉ có trạng thái cũ), nên không có phần đã làm cần gỡ; plan bàn giao làm theo spec này.

## 9. Kiểm thử

- Domain: máy trạng thái (mọi cạnh ở §4, kể cả đặt lại đồng hồ 3 ngày, hết lượt, cho thêm vòng); kiểm tra đầu vào nộp bàn giao (3–20 ảnh mẫu đã xử lý, URL hợp lệ, `photoCount` > 0); ai được nộp (thợ hay studio).
- Rules: khách không đọc được `private/delivery` trước `approved`; đọc được sau; chỉ thợ tải lên `deliveryUploads` và không ai đọc tệp sạch; chỉ thợ đọc `deliverySamples/{fileId}`; xác nhận bản sạch đã xoá hoàn toàn.
- Functions: watermark tạo đúng kích thước và không giữ metadata gốc (EXIF); job tự đồng ý và hết 48 giờ chuyển mốc 2 đúng một lần; dọn dẹp ảnh mẫu sau 90 ngày.
- App: S05.06 ba trạng thái (chờ, hết lượt, đã mở), S05.07, S06.07; golden S05.06.

## 10. Chia việc

1. Domain + Functions + rules: trạng thái, `deliveries`, link riêng, watermark, job.
2. App: S06.07, S05.06, S05.07, thông báo.
