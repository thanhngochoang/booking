# Studio tuyển thợ và cộng tác viên (S27)

Ngày: 2026-10-07 · Trạng thái: đã chốt với chủ dự án (các câu hỏi ở §2) · Dựa trên: `2026-10-06-studio-members-design.md` (S26: thành viên, giao thợ, đánh giá hai bên), `2026-10-06-identity-verification-design.md` (V2: chỉ thợ đã xác minh nhận việc), `2026-10-06-payments-payouts-design.md` (tiền 100% trước, giữ, nhả hai mốc), `2026-10-06-tomato-brick-reviews-design.md`. Nghiên cứu pháp lý và các nền tảng tương tự: `docs/research/2026-10-07-studio-collaborators.md`.

## 1. Mục tiêu

Studio đăng tin tuyển thợ. Tin chỉ thợ và studio nhìn thấy, khách thì không. Thợ đã xác minh ứng tuyển. Studio nhận thợ theo một trong hai cách:

- **Cộng tác viên (CTV):** làm theo từng buổi chụp, không độc quyền, không vào studio.
- **Thành viên:** vào studio theo S26.

Studio giao từng booking cho CTV như giao cho thành viên. Khách vẫn trả 100% cho studio, còn studio tự trả công CTV ngoài app.

## 2. Quyết định đã chốt

| # | Quyết định | Nguồn |
|---|---|---|
| R1 | Chỉ **studio đã xác minh** (`acceptingOrders`) được đăng tin tuyển, **miễn phí**. Thu phí đẩy tin để sau. | chủ dự án 2026-10-07 |
| R2 | **Mọi thợ** (kể cả chưa xác minh) xem được tin; **ứng tuyển cần đã xác minh** danh tính (S21). | chủ dự án |
| R3 | Tin chỉ hiện cho tài khoản có hồ sơ nhà cung cấp (thợ cá nhân, NAG, studio). Khách và người chưa đăng nhập không đọc được. Tin không lên feed, tìm kiếm của khách hay link chia sẻ. | chủ dự án |
| R4 | Hai loại tin: `collaborator` (cộng tác theo việc) và `member` (vào studio, S26). **Không có loại "nhân viên chính thức"**, để tránh phạm vi dịch vụ việc làm. | chủ dự án, nghiên cứu §5 |
| R5 | **Tiền công CTV do studio trả ngoài app.** App chỉ ghi "Đã trả / Đã nhận", gắn cờ khi studio không trả và không bảo lãnh thù lao. Tiền booking vẫn 100% về studio theo hai mốc (S26 T11). Nền tảng không chi hộ, không khấu trừ thuế cho CTV. | chủ dự án (phương án B+) |
| R6 | Cộng tác **không độc quyền**: thành viên của studio A được làm CTV cho studio B. CTV vẫn nhận booking cá nhân. Lịch bận dùng chung (S26 T1). | chủ dự án |
| R7 | Quan hệ cộng tác cần hai bên đồng ý. Mỗi buổi được giao, CTV phải **chấp nhận trong 6 giờ**; từ chối không tính vi phạm. | nghiên cứu §3.3 |
| R8 | Liên hệ khách mở cho CTV chỉ khi **đồng thời**: CTV được giao, đã chấp nhận, và khách đã thanh toán. Liên hệ đóng khi CTV bị đổi, hoặc khi booking xong/huỷ được 7 ngày. | CLAUDE.md "Money and contact rules", S26 §5.7 |

## 3. Tin tuyển

### 3.1 Dữ liệu

`recruitPosts/{postId}` (ULID). Chỉ server ghi.

| Trường | Ghi chú |
|---|---|
| `studioId` | Studio đăng tin |
| `kind` | `collaborator` \| `member` |
| `title` | 8–80 ký tự |
| `specialties[]` | Mã thể loại (như S08.02), 1–4 mục |
| `areas[]` | Mã khu vực (như S02.05), 1–5 mục |
| `frequency` | `occasional` (vài buổi/tháng) \| `weekly` \| `seasonal` (mùa cưới, Tết…) |
| `feeHint` | `{type: 'per_shoot', amount}` (VND, số nguyên) hoặc `{type: 'negotiable'}` |
| `requirements` | Tối đa 600 ký tự. Lọc số điện thoại, Zalo, link bằng bộ lọc chat hiện có. |
| `status` | `open` \| `closed` \| `expired` |
| `createdAt`, `expiresAt` | `expiresAt` = tạo + 30 ngày; gia hạn 1 lần thêm 30 ngày |
| `renewed` | |
| `applicationCount` | |

Giới hạn: một studio có tối đa **3 tin `open`**; mỗi ngày đăng hoặc đóng tối đa 5 lần.

### 3.2 Ai thấy

- **Rules:** `read` khi người đọc có hồ sơ nhà cung cấp (theo vai trò tài khoản, không theo màn hình). Một tài khoản vừa là khách vừa là thợ chỉ thấy tin khi đang ở vai trò thợ. Rules-test có ca "khách không đọc được tin".
- **Danh sách (S27.01):** lọc theo khu vực, thể loại, loại tin; sắp theo độ khớp với hồ sơ thợ (khu vực, thể loại), sau đó theo ngày đăng.
- **Thông báo `recruit_post_new`:** chỉ gửi cho thợ khớp cả khu vực và thể loại. Mỗi thợ nhận tối đa 3 thông báo loại này mỗi ngày.

### 3.3 Ứng tuyển

`recruitApplications/{postId}_{uid}`: `status` (`applied` \| `accepted` \| `declined` \| `withdrawn` \| `expired`), `message` (≤ 400 ký tự, có lọc liên hệ), `samplePostIds[]` (≤ 3 bài portfolio của chính thợ), `createdAt`, `expiresAt` (= tạo + 7 ngày), `respondedAt?`.

- Chỉ thợ đã xác minh ứng tuyển được. Thợ đang là thành viên của chính studio đó thì không ứng tuyển tin của studio ấy.
- Mỗi tin một ứng tuyển. Mỗi thợ có tối đa 10 ứng tuyển đang mở, và ứng tuyển tối đa 3 lần mỗi ngày.
- **Studio nhận ứng tuyển:**
  - Tin `collaborator`: tạo quan hệ cộng tác `active` (§4), vì hai bên đã đồng ý.
  - Tin `member`: đi theo luật S26 như một yêu cầu xin vào được duyệt, gồm `membership_conflict`, `cooldown`, `studio_full`. Lỗi nào thì báo đúng lỗi đó.
- Studio không trả lời trong 7 ngày thì ứng tuyển chuyển `expired`, do job định kỳ đang có xử lý.

## 4. Quan hệ cộng tác

`studio_collaborations/{studioId}_{uid}`, tách khỏi `studio_members`. Chỉ server ghi; studio và thợ trong quan hệ đọc được.

| Trường | Ghi chú |
|---|---|
| `status` | `invited` \| `requested` \| `active` \| `declined` \| `cancelled` \| `expired` \| `ended` |
| `initiatedBy` | `studio` \| `collaborator` \| `application` |
| `createdAt`, `expiresAt` | `expiresAt` = tạo + 7 ngày |
| `activeAt?`, `endedAt?`, `endedBy?` | |
| `defaultFee?` | VND, mức gợi ý khi giao việc |

**Vòng đời:** giống S26 §3.2. Studio có thể mời trực tiếp mà không cần tin tuyển. `active → ended` do bất kỳ bên nào kết thúc.

**Luật** (`packages/domain/src/studio_collaboration.ts`, hằng số đặt cùng file):

| Luật | Chi tiết | Lỗi |
|---|---|---|
| Ai tham gia | Studio `providerType = studio`, đã xác minh. CTV là thợ cá nhân hoặc NAG, đã xác minh. | `not_accepting_orders` / `invalid_argument` |
| Không độc quyền | Được làm thành viên ở studio khác. Không được làm CTV cho chính studio mình đang là thành viên. | `membership_conflict` |
| Số quan hệ | CTV có ≤ **5** cộng tác `active`. Studio có ≤ **5** CTV khi chưa xác minh doanh nghiệp, ≤ **50** khi đã xác minh; tính riêng với hạn 3/30 thành viên. Lời mời chờ ≤ 5. | `collab_full` |
| Thao tác mỗi ngày | Studio ≤ 10 (mời, huỷ, duyệt, kết thúc); CTV ≤ 5. Ngày tính theo giờ Việt Nam. | `rate_limited` |
| Mời lại | Sau `ended`, phải đợi **3 ngày** mới mời lại cùng studio. Không có thời gian nghỉ 7 ngày như thành viên, vì cộng tác không độc quyền. | `cooldown` |
| Khoá khi còn việc | Không `ended` được khi CTV còn booking được giao chưa xong, hoặc đang khiếu nại. | `member_busy` |

**Điều khoản hiện khi đồng ý cộng tác:** đây là mẫu tối thiểu, phải được luật sư duyệt trước khi chạy thật.

- Đây là hợp đồng dịch vụ theo từng việc. CTV tự quyết cách làm, không có giờ làm cố định, không độc quyền.
- Thù lao do hai bên thoả thuận từng việc. Studio trả ngoài app; nền tảng không bảo lãnh.
- CTV cam kết không chào trực tiếp khách mà studio giao trong 6 tháng.

## 5. Giao việc cho CTV

Phần này mở rộng S26 §5.2 (`assignBooking`). Mỗi phần tử `assignments[]` thêm các trường:

| Trường | Ghi chú |
|---|---|
| `assigneeKind` | `member` \| `collaborator` |
| `offerExpiresAt` | = giao + 6 giờ, nhưng không muộn hơn `assignDeadline` |
| `acceptedAt?`, `declinedAt?` | |

Booking thêm `assigneeKind` và `assigneeAccepted: bool`.

**Thù lao không nằm trên booking.** Khách đọc được toàn bộ document booking, nên nếu để thù lao ở đó thì khách sẽ thấy chi phí của studio. Vì vậy thù lao, trạng thái offer và bản ghi trả tiền nằm ở `collab_jobs/{bookingId}_{collaboratorId}`. Chỉ studio và CTV đó đọc được document này. Thù lao (`agreedFee`, VND) bắt buộc khi giao cho CTV, gợi ý sẵn `defaultFee`. (Sửa 2026-10-07 theo plan S27.)

- **Sheet S26.04 (giao thợ):** danh sách chọn gồm thành viên và CTV `active`, chia hai nhóm "Thành viên" và "Cộng tác viên". Khi chọn CTV thì có thêm ô "Thù lao" (VND).
- **S27.07 (CTV nhận việc):** CTV mở sheet thấy tóm tắt buổi chụp (không có liên hệ khách), thù lao và hạn trả lời, rồi bấm "Nhận việc" hoặc "Từ chối".
  - Hết 6 giờ không trả lời coi như từ chối (job định kỳ đang có xử lý).
  - Khi CTV từ chối, studio được báo và giao người khác. Hạn 24 giờ của T6 vẫn áp dụng; nếu quá hạn thì xử lý theo S26 T8.
- **Phía khách:** khách thấy khối "Thợ chụp cho bạn" sau khi CTV chấp nhận, với nhãn "Cộng tác với {Studio}". Quyền xin đổi thợ theo S26.05. Studio vẫn chịu trách nhiệm với khách.
- **Lịch bận:** chặn lịch của CTV từ lúc chấp nhận.

### 5.1 Thù lao ngoài app

`collab_jobs/{bookingId}_{collaboratorId}.pay`: `{amount, status: 'due' | 'paid_reported' | 'received' | 'disputed', paidAt?, method?: 'bank' | 'cash' | 'other', receivedAt?}`. Khách không đọc được.

- Khi mốc 1 được nhả cho studio, trạng thái thành `due` và studio nhận nhắc: "Trả {tên} {số tiền}".
- Studio bấm **"Đã trả"** (chọn ngày và cách trả). CTV bấm **"Đã nhận"**, hoặc **"Chưa nhận"** (`disputed`).
- Quá 7 ngày vẫn `due`, hoặc có `disputed`, thì `studio.unpaidCollaboratorCount + 1` để staff xem. Lặp lại 3 lần trong 90 ngày thì tạm khoá quyền đăng tin và mời CTV của studio (`recruitBlockedUntil`).
- Khoản từ 5.000.000đ/lần trở lên: studio thấy nhắc một lần: "Khoản từ 5.000.000đ/lần có thể phải khấu trừ thuế TNCN 10%; hãy hỏi kế toán". Đây là ngưỡng mới từ 01/07/2026, chưa có xác nhận của kế toán.
- Studio xuất được bảng kê thù lao theo tháng (CSV tạo trên máy).

## 6. Liên hệ, đánh giá, chống "đi đường vòng"

- **Liên hệ (R8):** CTV chỉ đọc được booking mà mình là `assigneeId`. CTV không thấy danh sách khách hay booking khác của studio. Chat CTV–khách đi trong hội thoại của booking, có bộ lọc liên hệ. Chat studio–CTV là một hội thoại riêng, loại `collab`.
- **Đánh giá:** như S26 §6. Khách đánh giá thợ cuối cùng (CTV) và studio thành hai bản ghi. Đánh giá CTV cộng vào % cà chua của chính CTV, kèm tag "Qua {Studio}". Studio và CTV không đánh giá nhau trong phase 1.
- **Chống đi đường vòng:** gồm bộ lọc liên hệ, liên hệ chỉ mở theo R8, và cam kết 6 tháng ở §4. Nếu một CTV có từ 2 booking cá nhân với cùng khách mà studio đã giao, trong vòng 6 tháng, thì gắn cờ cho staff. Hệ thống chỉ ghi nhận, không tự xử lý. Khách vẫn được đặt thợ trực tiếp; app không chặn quyền chọn của khách.

## 7. Màn hình (S27 · Studio tuyển thợ)

Mock là bước đầu tiên của plan; chưa có mock.

| Mã | Màn | Route | Ai |
|---|---|---|---|
| S27.01 | Tin tuyển: danh sách, lọc khu vực / thể loại / loại; vào từ tab "Tuyển thợ" trong Công việc (S06.01) | `/recruit` | thợ, studio |
| S27.02 | Chi tiết tin: studio, % cà chua của studio, loại, thù lao tham khảo, yêu cầu; nút chính "Ứng tuyển" (thợ chưa xác minh thấy "Xác minh để ứng tuyển" → S21.02) | `/recruit/:id` | thợ, studio |
| S27.03 | Ứng tuyển (sheet): lời nhắn, chọn ≤ 3 ảnh portfolio, điều khoản cộng tác (tin `collaborator`) | — | thợ |
| S27.04 | Đăng / sửa tin (studio): loại, tiêu đề, thể loại, khu vực, tần suất, thù lao, yêu cầu; "Còn {n}/3 tin mở" | `/studio/recruit/new` | studio |
| S27.05 | Tin của studio và ứng viên: mỗi tin có số ứng viên; danh sách ứng viên (avatar, % cà chua, 3 ảnh, lời nhắn); "Nhận" / "Từ chối"; đóng / gia hạn tin | `/studio/recruit` | studio |
| S27.06 | Cộng tác: studio xem CTV (thù lao gợi ý, "{m} việc đang giao", trạng thái trả tiền, "Kết thúc"); thợ xem "Studio cộng tác", lời mời, việc chờ nhận, mục "Thù lao" (Đã nhận / Chưa nhận) | `/collab` | studio, thợ |
| S27.07 | Nhận việc cộng tác (sheet): buổi chụp, thù lao, hạn trả lời; "Nhận việc" / "Từ chối" | — | CTV |

Thay đổi ở màn cũ:

- **S06.01:** thêm tab "Tuyển thợ"; booking được giao có nhãn "Cộng tác · {Studio}".
- **S26.04:** thêm nhóm "Cộng tác viên" và ô "Thù lao".
- **S05.02:** nhãn "Cộng tác với {Studio}" trong khối "Thợ chụp cho bạn".
- **S09.02:** thêm dòng "Cộng tác" (studio và thợ).
- **S03.01:** hồ sơ studio có dòng "Đang tuyển · {n} tin", chỉ hiện cho thợ và studio.

## 8. Thông báo (S17)

| Loại | Gửi cho | Ghi chú |
|---|---|---|
| `recruit_post_new` | Thợ khớp tin | ≤ 3 thông báo mỗi ngày |
| `recruit_application_new` | Studio | Gom theo tin |
| `recruit_application_result` | Thợ | |
| `collab_invite` | Thợ | |
| `collab_invite_result` | Studio | |
| `collab_assignment_offer` | CTV | Hạn 6 giờ |
| `collab_assignment_result` | Studio | |
| `collab_pay_due` | Studio | |
| `collab_pay_reported` | CTV | |
| `collab_pay_disputed` | Studio, staff | |

Hook: `notifyRecruitPostNew`, `notifyRecruitApplicationNew`, `notifyRecruitApplicationResult`, `notifyCollabInvite`, `notifyCollabInviteResult`, `notifyCollabAssignmentOffer`, `notifyCollabAssignmentResult`, `notifyCollabPayDue`, `notifyCollabPayReported`, `notifyCollabPayDisputed` trong `packages/domain/src/notification_hooks.ts` (#138), mười loại trên; #151 gọi, giới hạn 3 thông báo mỗi thợ mỗi ngày và 200 người nhận nằm ở `notifyRecruitMatches` của #151. Hook của `collab_pay_disputed` chỉ gửi cho Studio; thông báo cho staff không thuộc danh mục S17.

## 9. Rules, job, chi phí

- **Rules:**
  - Tin tuyển chỉ đọc theo R3.
  - Ứng tuyển chỉ đọc bởi thợ ứng tuyển và studio của tin.
  - Quan hệ cộng tác chỉ đọc bởi hai bên.
  - `bookings` cho CTV đọc khi CTV là `assigneeId`.
  - Mọi ghi đi qua callable.
- **Job:** dùng lại job định kỳ của S26 (§5.5, mỗi 15 phút), không thêm lịch mới. Job này hết hạn ứng tuyển (7 ngày), lời mời cộng tác, offer giao việc (6 giờ) và tin tuyển (30 ngày), và bật trạng thái `due` cho nhắc trả thù lao.
- **Chi phí:** xem `2026-10-07-google-cloud-costs.md` §14. Phần lớn là đọc danh sách tin (phân trang 20, dùng `get` chứ không dùng listener) và thông báo khớp tin (truy vấn thợ theo khu vực và thể loại khi đăng tin, tối đa 200 thợ mỗi tin). Không có API trả phí mới.

## 10. Ngoài phạm vi (phase sau)

- App chia tiền hoặc chi hộ cho CTV, và nền tảng khấu trừ thuế 10% (phương án A). Chỉ làm khi luật sư và kế toán đã xác nhận tư cách bên chi trả, cách tránh thuế hai lớp, và có đối tác chi hộ.
- Studio và CTV đánh giá lẫn nhau.
- Thù lao theo %.
- Thu phí đẩy tin tuyển.
- Vai trò "quản lý" trong studio; giao nhiều thợ cho một booking.
- Loại tin "nhân viên chính thức".

## 11. Câu hỏi còn mở (pháp lý, không chặn làm)

1. Mẫu điều khoản cộng tác và cam kết không chào khách 6 tháng có hiệu lực không (luật sư).
2. Tin tuyển miễn phí có thuộc "dịch vụ việc làm" có điều kiện không (luật sư).
3. Cập nhật spec thanh toán (mục khấu trừ) theo NĐ 252/2026, NĐ 253/2026, TT 87/2026 và TT 90/2026 (kế toán).
