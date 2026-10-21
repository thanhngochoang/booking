# Studio và thành viên (S26)

Ngày: 2026-10-06 · Trạng thái: chờ duyệt · Hoàn thành phần "Studio nhiều thành viên" mà `2026-10-05-provider-types-portfolio-jobs-design.md` để ngoài phạm vi (mục đầu và câu hỏi mở 8). Dựa trên: `2026-10-06-tomato-brick-reviews-design.md` (đánh giá) và `2026-10-06-delivery-preview-unlock-design.md` (bàn giao).

## 1. Mục tiêu

Một studio có nhiều thợ. Studio chốt giá với khách rồi giao buổi chụp cho một thợ thành viên; studio lo bàn giao ảnh. Khách biết trước ai chụp cho mình, được xin đổi, và đánh giá riêng thợ lẫn studio. Việc thêm/bỏ thợ có cơ chế chống spam.

## 2. Quyết định đã chốt

| # | Quyết định |
|---|---|
| T1 | Thợ thuộc **tối đa một studio** một lúc, **vẫn nhận booking cá nhân**; lịch bận dùng chung. |
| T2 | Vào studio cần **hai bên đồng ý** (studio mời → thợ chấp nhận, hoặc thợ xin → studio duyệt); lời mời/xin vào hết hạn sau 7 ngày. |
| T3 | Rời hoặc bị bỏ thì **7 ngày** sau mới vào studio nào (kể cả studio cũ). |
| T4 | Không rời/bỏ được khi thợ còn booking studio được giao chưa xong. |
| T5 | Giới hạn theo xác minh: tối đa **3** thợ (chưa xác minh) / **30** (đã xác minh); giới hạn thao tác mỗi ngày. |
| T6 | Studio chốt giá (gói hoặc báo giá) rồi **giao một thợ chậm nhất 24 giờ trước buổi chụp**. |
| T7 | Khách được báo, xem hồ sơ thợ và **xin đổi 1 lần**; studio trả lời trong 6 giờ. |
| T8 | Studio quá hạn giao, từ chối/không trả lời yêu cầu đổi, hoặc tự đổi thợ khi còn < 24 giờ → khách được **huỷ và hoàn 100%**. |
| T9 | **Studio bàn giao ảnh** (spec bàn giao hai lớp); thợ được giao chỉ lo buổi chụp. |
| T10 | Khách **đánh giá cả thợ và studio**, mỗi bên một bộ cà chua/gạch và nhận xét riêng. |
| T11 | Tiền của booking studio trả cho studio theo hai mốc; studio tự chia với thợ ngoài app. |
| T12 | Chỉ chủ studio quản lý thành viên và chốt giá (chưa có vai trò "quản lý"). |

## 3. Thành viên

### 3.1 Dữ liệu

`studio_members/{studioId}_{memberId}_{createdAtMs}` (mỗi quan hệ một id mới, Decision 1 của plan #136; SQL: bảng `studio_members`, khoá `(studio_id, member_id, created_at)`). Chỉ server ghi; rules cho studio và thợ trong quan hệ đọc.

| Trường | Ghi chú |
|---|---|
| `studioId`, `memberId` | |
| `status` | `invited`, `requested`, `active`, `declined`, `cancelled`, `expired`, `left`, `removed` |
| `initiatedBy` | `studio` \| `member` |
| `createdAt`, `expiresAt` (= tạo + 7 ngày), `respondedAt?`, `joinedAt?`, `endedAt?`, `endedBy?` | |

Mọi quan hệ có id mới `{studioId}_{memberId}_{createdAtMs}`; một quan hệ kết thúc rồi mở lại thì tạo bản ghi mới, lịch sử giữ nguyên để tính thời gian nghỉ và giới hạn theo ngày. "Một quan hệ mở mỗi cặp" và "một studio `active` mỗi thợ" do domain giữ trong transaction: `photographers/{memberId}.studioId` là khoá chung nên hai lời nhận song song chỉ một cái thành công (cái kia `membership_conflict`).

**Thành viên công khai** đọc từ `photographers/{uid}.studioId` (công khai, chỉ server ghi, kèm `studioJoinedAt`), không đọc từ `studio_members` (chỉ hai bên xem được, §8). Hàng "Thành viên" ở S03.01 truy vấn `photographers` theo `studioId == studio`, sắp theo `studioJoinedAt`, tối đa 10; `memberCount` của studio cho số "+n".

Thêm vào hồ sơ: thợ có `studioId?`; studio có `memberCount`, và bộ đếm vi phạm `lateAssignCount`, `changeDeclinedCount`, `lateReassignCount`, `lateDeliveryCount` (chỉ server ghi, staff xem; chưa hiện công khai, chưa dùng xếp hạng).

### 3.2 Vòng đời

```
invited ──(thợ chấp nhận)──▶ active        invited ──(thợ từ chối | studio huỷ | 7 ngày)──▶ declined | cancelled | expired
requested ──(studio duyệt)──▶ active       requested ──(studio từ chối | thợ huỷ | 7 ngày)──▶ declined | cancelled | expired
active ──(thợ rời)──▶ left                 active ──(studio bỏ)──▶ removed
```

### 3.3 Luật (`packages/domain/src/studio_membership.ts`)

| Luật | Chi tiết | Lỗi |
|---|---|---|
| Ai tham gia | Studio là `providerType = studio`; thành viên là thợ `individual` (kể cả hạng NAG) đã hoàn tất hồ sơ; studio không làm thành viên | `invalid_argument` |
| Một studio | Thợ đang `active` ở studio khác thì không được mời/xin/chấp nhận | `membership_conflict` |
| Thời gian nghỉ | Sau `left`/`removed`: thợ không thành `active` ở studio nào trong 7 ngày kể từ `endedAt` | `cooldown` |
| Khoá khi còn việc | Không `left`/`removed` khi thợ còn booking studio được giao chưa `completed`/`cancelled`, hoặc đang khiếu nại | `member_busy` |
| Số thợ | `active` + lời mời đang chờ ≤ 3 (studio chưa xác minh) / 30 (đã xác minh); lời mời đang chờ ≤ 5 | `studio_full` |
| Thao tác mỗi ngày | Studio ≤ 5 (mời, huỷ mời, duyệt, bỏ); thợ ≤ 3 (xin vào, huỷ xin, rời); ngày tính theo giờ Việt Nam; chấp nhận/từ chối lời mời không tính | `rate_limited` |
| Chuyển loại | Studio chỉ về Cá nhân khi `memberCount = 0`; thợ đang là thành viên không chuyển thành Studio | `membership_conflict` |
| Xoá tài khoản | Quan hệ kết thúc (`endedBy = system`), không tính thời gian nghỉ; xoá vẫn bị chặn nếu còn việc (spec chính S22.02) | |

Các hằng số (`INVITE_TTL_DAYS = 7`, `COOLDOWN_DAYS = 7`, `MAX_MEMBERS_UNVERIFIED = 3`, `MAX_MEMBERS_VERIFIED = 30`, `MAX_PENDING_INVITES = 5`, `STUDIO_DAILY_ACTIONS = 5`, `MEMBER_DAILY_ACTIONS = 3`) đặt cùng file để đổi một chỗ.

Callable: `inviteMember`, `cancelInvite`, `requestToJoin`, `cancelJoinRequest`, `respondInvite` (thợ), `respondJoinRequest` (studio), `leaveStudio`, `removeMember`. Hết hạn lời mời: job định kỳ (§5.5).

## 4. Màn hình (S26 · Studio và thành viên)

| Mã | Màn | Route | Ai |
|---|---|---|---|
| S26.01 | Thành viên studio | `/studio/members` | chủ studio |
| S26.02 | Mời thợ (sheet) | — | chủ studio |
| S26.03 | Studio của tôi | `/me/studio` | thợ |
| S26.04 | Giao thợ (sheet) | — | chủ studio |
| S26.05 | Xin đổi thợ (sheet) | — | khách |

- **S26.01**: "Thành viên"; dòng "{n}/{max} thợ · còn {k} thao tác hôm nay"; danh sách thành viên (avatar, tên, % cà chua cá nhân, "{m} việc đang giao"; chạm mở hồ sơ thợ); mục "Đang chờ": lời mời đã gửi (hạn còn lại, "Huỷ") và yêu cầu xin vào ("Duyệt", "Từ chối"); nút chính "Mời thợ" (→ S26.02). "Bỏ khỏi studio" trong menu của từng thành viên → sheet xác nhận nút đỏ; bị khoá thì sheet nói lý do ("Còn 2 buổi chụp được giao").
- **S26.02**: ô tìm thợ theo tên; mỗi kết quả: avatar, tên, %; nút viền "Mời"; thợ đang ở studio khác hiện mờ "Đang ở {Studio}"; thợ đang nghỉ hiện mờ "Mời được từ {ngày}"; dòng "Lời mời hết hạn sau 7 ngày · tối đa 5 lời mời chờ".
- **S26.03**: thẻ studio hiện tại ("Thành viên từ {tháng}", "{m} việc được giao"), nút chữ đỏ "Rời studio" → sheet xác nhận; mục "Lời mời" (Chấp nhận / Từ chối; mờ khi đang ở studio khác); dòng giải thích thời gian nghỉ 7 ngày.
- **S26.04, S26.05**: §5.
- **Thay đổi màn cũ**:
  - S03.01 (hồ sơ studio): ô thống kê % cà chua của studio · buổi chụp · **thành viên** · kinh nghiệm; hàng "Thành viên" (avatar, tên, % cá nhân); thợ cá nhân xem hồ sơ studio thấy nút viền "Xin gia nhập".
  - S03.01 (hồ sơ thợ thành viên): nhãn "Thành viên của {Studio}" dưới tên.
  - S09.02 Cài đặt: dòng "Thành viên studio" (studio) / "Studio của tôi" (thợ).
    Hai dòng đã có sẵn trong `SettingsScreen` (#148, `settings-studio-members` và `settings-my-studio`), chỉ hiện khi `studioRoutesReadyProvider` (`lib/features/settings/settings_links.dart`) là true; bật khi có `/studio/members` (S26.01) và `/me/studio` (S26.03).
  - S06.01 Công việc: booking studio được giao có nhãn "Giao bởi {Studio}".

## 5. Booking với studio

### 5.1 Chốt giá và tiền

Dùng luồng hiện có: gói của studio hoặc báo giá (S16, báo giá trong chat). Booking studio có `photographerId` = studio (bên nhận tiền theo hai mốc, P2 trong ghi chú điều khoản). Booking thêm `isStudio: bool` (suy ra lúc tạo từ `providerType`).

### 5.2 Giao thợ

Booking thêm: `assigneeId?`, `assigneeKind?` (chỉ `member` ở S26; S27 thêm `collaborator`), `assignDeadline`, `assignments: [{assigneeId, assigneeKind, at, by, reason?, late}]`, `assignOverdue: bool`.
- **Hạn giao** (Decision 8 của plan #136): `assignDeadline = max(startAt − 24 giờ, lúc tạo + 2 giờ)`, không vượt `startAt`. Booking đặt khi còn dưới 24 giờ thì studio có 2 giờ để giao thay vì bị từ chối (mặc định của "Needs the owner 1"). Các trường studio do bộ dựng booking nháp dùng chung ghi khi `providerType = studio`, nên báo giá hay cộng tác viên của studio cũng có cùng trường.

- **S26.04** (sheet, chủ studio, mở từ chi tiết booking và từ S06.01): tóm tắt booking, "Hạn giao thợ: {giờ ngày} (còn {x})"; danh sách thành viên chọn đơn, kèm trạng thái rảnh đúng khung giờ và % cà chua; thành viên bận (booking cá nhân hoặc studio khác trùng giờ) hiện mờ "Bận {giờ}"; nút chính "Giao cho {tên}".
- Callable `assignBooking`: kiểm tra thành viên `active`, rảnh, booking chưa qua `shot`. Ghi `assigneeId`, thêm vào `assignments`, chặn lịch của thợ, thêm thợ vào hội thoại booking, báo khách.
- Studio đổi thợ (chủ động) dùng cùng callable; thợ cũ rời hội thoại, liên hệ của thợ cũ đóng với khách. Đổi khi còn < 24 giờ → `lateReassignCount + 1` và khách được huỷ hoàn 100% (§5.4).
- Nhắc studio lúc còn 48 giờ và 26 giờ. Booking studio không chuyển sang `upcoming` khi chưa có `assigneeId`.
- **Trường sẵn cho S27** (Decision 9): `assigneeKind` (hiện chỉ `member`), `assignments[]` với `by`, `reason`, `late`; một điểm vào `assignBooking`; `StudioRoster.relationOf(studioId, uid)` trả `'member'` (S27 trả thêm `'collaborator'` từ bộ sưu tập riêng); `assignStatus: unassigned | assigned`, `assignedAt`, `assignRemindersSent`, `studioFault`, `assignmentReturned`, `changeRequest {at, note, respondBy, status, declineReason, answeredAt}`.
- Thợ được giao có nút "Trả việc" (lý do tuỳ chọn): studio được báo để giao người khác; `assigneeId` giữ nguyên cho tới khi studio giao lại.

### 5.3 Phía khách (S05.02, khối "Thợ chụp cho bạn")

| Tình huống | Hiển thị |
|---|---|
| Chưa giao, còn hạn | "Studio sẽ báo thợ chụp trước {giờ ngày}" |
| Đã giao | avatar, tên, `ProviderMark`, % cà chua, "Xem hồ sơ", nút viền "Xin đổi thợ" (còn lượt) |
| Quá hạn chưa giao (`assignOverdue`) | cảnh báo "Studio chưa báo thợ chụp đúng hạn" + nút chữ đỏ "Huỷ và hoàn 100%" (sheet xác nhận). Khách có thể chờ; studio giao muộn thì booking chạy tiếp |
| Studio đổi thợ khi còn < 24 giờ | thông báo + cùng nút huỷ hoàn 100% |

### 5.4 Xin đổi thợ (S26.05)

- Một lần mỗi booking. Sheet: thợ hiện tại; "Lý do (tuỳ chọn)"; "Studio trả lời trong 6 giờ"; "Nếu studio từ chối hoặc không trả lời, bạn được huỷ và hoàn 100%"; nút chính "Gửi yêu cầu đổi".
- Booking thêm `changeRequest?: {at, note?, respondBy, status: pending | reassigned | declined | expired, declineReason?}`. `respondBy` = min(`at` + 6 giờ, `startAt`).
- Studio: giao người khác (→ `reassigned`, khách được báo) hoặc từ chối kèm lý do (→ `declined`). Quá `respondBy` → `expired`.
- `declined`/`expired`: `changeDeclinedCount + 1`; khách chọn giữ thợ hiện tại hoặc huỷ hoàn 100%.

Huỷ do studio (quá hạn giao, từ chối đổi, đổi muộn): toàn bộ tiền `refunded`, booking `cancelled` với `cancelledBy = studio_fault`. Các trường hợp huỷ khác giữ chính sách cũ.

### 5.5 Job định kỳ

Cloud Function mỗi 15 phút (dùng chung với spec bàn giao): đánh dấu `assignOverdue` và báo khách; cho `changeRequest` hết hạn; cho lời mời/xin vào hết hạn; nhắc giao thợ (48 giờ, 26 giờ). Mỗi việc idempotent (ghi mốc đã xử lý).

**Như đã làm (#136):** không thêm job Scheduler mới. Các quét chạy bên trong `bookingClock` (`functions/src/scheduled/booking_clock.ts`, `BookingClockExtras.studio`), thành hai bước riêng, mỗi bước trong try/catch của nó: (1) quan hệ (lời mời/xin vào hết hạn, báo "sắp hết hạn" trước 24 giờ), (2) giao thợ (đánh dấu `assignOverdue`, nhắc 48 giờ và 26 giờ, `changeRequest` hết hạn). Quét giao thợ dùng chỉ mục `(assignStatus, assignOverdue, status, assignDeadline)`; thông báo lỗi (`notifyFailed > 0`) được ghi log để cảnh báo. Vì Blaze đang tắt (`BLAZE_ENABLED`), Functions không deploy lên dev; chạy trên emulator.

### 5.6 Buổi chụp và bàn giao

| Việc | Booking cá nhân | Booking studio |
|---|---|---|
| "Đã chụp xong" (mốc 1) | thợ | thợ được giao hoặc chủ studio |
| Nộp bàn giao, vòng sửa, cho thêm vòng (S06.07) | thợ | **chỉ studio** |
| Hạn giao ảnh, giao trễ (hoàn 100% mốc 2) | tính cho thợ | tính cho studio (`lateDeliveryCount + 1`) |

Thợ được giao không thấy lối vào S06.07. Chuyển ảnh gốc từ thợ sang studio để hậu kỳ nằm ngoài app.

### 5.7 Liên hệ

Gọi/Zalo/WhatsApp của studio mở sau khi thanh toán (luật hiện có). Thợ được giao đọc liên hệ của khách theo cùng luật mở khoá như studio (người gặp khách cần số, Decision 17 của plan #136) và thấy booking, sự kiện của booking; đổi thợ thì thợ cũ mất quyền đọc. Chiều ngược lại (khách nhận kênh gọi/Zalo/WhatsApp riêng của thợ được giao) **chưa làm** trong S26: mock không có nút, khách nói chuyện với thợ trong chat của booking. Số điện thoại vẫn không nằm trong hồ sơ công khai.

## 6. Đánh giá hai bên

- Với booking studio, S05.05 có **hai khối** xếp dọc: "Thợ {tên}" (lý do gạch như spec cà chua/gạch §3.1) và "Studio {tên}" (lý do gạch riêng: `slow_response` Tư vấn chậm (nhãn theo mock), `price_changed` Đổi giá, `late_assignment` Báo thợ trễ, `poor_assignment` Giao thợ không hợp, `other` Khác). Mỗi khối có `VerdictPad`, chip lý do khi là gạch, và **ô nhận xét riêng** (10–1000 ký tự). Chia sẻ ảnh giữ một section chung; bài "Buổi chụp thật" gắn tag cả thợ và studio. Nút chính "Gửi 2 đánh giá" chỉ bật khi đủ cả hai khối; dòng nhắc nói khối nào còn thiếu.
- Người được đánh giá là thợ **cuối cùng** được giao.
- Dữ liệu (mở rộng spec cà chua/gạch §3.1): review thêm `subjectType: photographer | studio`, `subjectId`. Booking studio có hai bản ghi trong cùng transaction của `submitReview`: `reviews/{bookingId}` (thợ) và `reviews/{bookingId}_studio` (studio). Thiếu một trong hai → `invalid_argument`. Booking cá nhân giữ một bản ghi. Luật đổi thành "**một đánh giá cho mỗi đối tượng** trong một booking".
- Thống kê: đánh giá thợ cộng vào % cá nhân của thợ; đánh giá studio cộng vào % của studio; không trộn.
- Hiển thị: tab Đánh giá của studio chỉ hiện đánh giá studio, mỗi lượt có tag "Chụp bởi {thợ}"; đánh giá thợ từ booking studio có tag "Qua {Studio}".
- Thông báo: thợ nhận về đánh giá của mình, studio nhận về đánh giá studio (mẫu như spec cà chua/gạch §7.4).
- Đánh giá mở khi booking `approved` (spec bàn giao).
- Mô hình đã sẵn (#130, `2026-10-06-tomato-brick-reviews-design.md` §3.1): review có `subjectType`/`subjectId`, doc id `reviewDocId(bookingId, 'studio')` = `{bookingId}_studio`, `countReview` đếm vào `review.subjectId`, `onReviewWrite` gọi `notifyReviewVerdict` cho từng bản. #130 chỉ ghi bản `photographer`; #136 thêm khối studio, các mã lý do riêng của studio (`slow_response`, `price_changed`, `late_assignment`, `poor_assignment`, `other`) vào `REVIEW_REASONS` hoặc bảng mã theo `subjectType`, và bản `{bookingId}_studio` trong cùng transaction của `submitReview`. Bản studio tạo với `countedAt` rỗng (để trigger đếm, thông báo và chấm huy hiệu).

## 7. Thông báo (S17)

`studio_invite`, `studio_join_request`, `studio_invite_accepted`, `studio_join_approved`, `studio_removed`, `studio_invite_expiring` (1 ngày trước hạn), `booking_assigned` (khách, thợ), `booking_reassigned` (khách, thợ cũ, thợ mới), `assign_reminder` (studio, 48 giờ / 26 giờ), `assign_overdue` (khách, studio), `change_requested` (studio), `change_answered` (khách), `assignment_returned` (studio, khi thợ "Trả việc").

Hook: `notifyStudioInvite`, `notifyStudioJoinRequest`, `notifyStudioInviteAccepted`, `notifyStudioJoinApproved`, `notifyStudioRemoved`, `notifyStudioInviteExpiring`, `notifyBookingAssigned`, `notifyBookingReassigned` (truyền `reassignedAt`), `notifyAssignReminder`, `notifyAssignOverdue`, `notifyChangeRequested`, `notifyChangeAnswered`, `notifyAssignmentReturned` trong `packages/domain/src/notification_hooks.ts` (#138); #136 là chỗ gọi duy nhất.

## 8. Rules và dữ liệu khác

- `studio_members`: chỉ server ghi; đọc khi `request.auth.uid` là `studioId` hoặc `memberId`.
- Booking: `assigneeId` được đọc booking như hai bên; trường riêng tư của booking (liên hệ) theo §5.7.
- SQL (`services/api`): migration mới thêm bảng `studio_members` (check `status`, unique một `active` mỗi `member_id` bằng partial unique index), cột booking (`assignee_id`, `assign_deadline`, `assign_overdue`, `change_request jsonb`), bảng `booking_assignments`, cột `photographers.studio_id`, `member_count` và bộ đếm vi phạm; `reviews` thêm `subject_type`, `subject_id`, khoá `(booking_id, subject_type)`.
- `data-model/domain-model.md`, `relational-schema.md`: thêm các thực thể và cột trên.

**Rules như đã làm (#136):** `studio_members` đọc bởi `studioId` hoặc `memberId`, ghi `false`; `studio_quota/{uid}` chỉ chủ đọc, ghi `false`; `studio_day_load/{id}` đọc và ghi `false` (tải theo ngày của studio, chỉ server); `photographerServerFieldsUntouched()` thêm `studioId`, `studioJoinedAt`, `studioCooldownUntil`, `memberCount`, `lateAssignCount`, `changeDeclinedCount`, `lateReassignCount`, `lateDeliveryCount`, `nameKey`, `assignableMembers`; trạng thái ngày `full` chỉ server ghi (client chỉ tạo `off`; studio được đổi `full` thành `off`). Booking cho `assigneeId` đọc; `private/delivery` vẫn chỉ thợ chính và khách đã duyệt. Bộ đếm `lateDeliveryCount` được lưu nhưng chưa có gì tăng nó cho tới #207.

## 9. Ngoài phạm vi

- Vai trò "quản lý" trong studio, nhiều chủ.
- Chia tiền studio–thợ trong app, hợp đồng lao động.
- Giao nhiều thợ cho một booking (thợ chính + phụ). Dòng "m thợ đi cùng" ở báo giá vẫn là thông tin khai báo.
- Hiện bộ đếm vi phạm công khai hoặc dùng để xếp hạng.
- Khách chọn trước một thành viên khi đặt.

## 10. Kiểm thử

- Domain: mọi cạnh của vòng đời; từng luật ở §3.3 (kể cả biên 7 ngày, 3/30, 5 lời mời, giới hạn ngày qua nửa đêm giờ Việt Nam); `assignBooking` (bận, không phải thành viên, quá `shot`); xin đổi (một lần, `respondBy` khi còn < 6 giờ, hết hạn); huỷ do studio hoàn 100%; review hai bản ghi trong một transaction.
- Rules: chỉ hai bên đọc `studio_members`; khách không thấy liên hệ thợ trước khi giao.
- Functions: job định kỳ idempotent; test tích hợp emulator theo mẫu hiện có.
- App: S26.01–S26.05; khối "Thợ chụp cho bạn" ba trạng thái; S05.05 hai khối; hồ sơ studio có hàng thành viên.

## 11. Chia việc (chạy sau plan cà chua/gạch và plan bàn giao)

1. Domain + Functions + rules: thành viên (§3).
2. Booking studio: giao thợ, xin đổi, job, hoàn tiền (§5).
3. Đánh giá hai bên (§6).
4. App: S26, thay đổi S03.01, S05.02, S05.05, S06.01, S09.02.
5. Gallery + tài liệu widget.
